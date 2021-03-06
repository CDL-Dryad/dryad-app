# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength

require_dependency 'stash_api/application_controller'
require_relative 'datasets/submission_mixin'
require 'stash/download/version_presigned'
require 'rsolr'

module StashApi
  class DatasetsController < ApplicationController
    include ActionView::Helpers::DateHelper
    include SubmissionMixin

    before_action :require_json_headers, only: %i[show create index update]
    before_action -> { require_stash_identifier(doi: params[:id]) }, only: %i[show download]
    before_action :setup_identifier_and_resource_for_put, only: %i[update em_submission_metadata set_internal_datum add_internal_datum]
    before_action :doorkeeper_authorize!, only: %i[create update]
    before_action :require_api_user, only: %i[create update em_submission_metadata]
    before_action :optional_api_user, except: %i[create update em_submission_metadata]
    before_action :require_permission, only: :update
    before_action :lock_down_admin_only_params, only: %i[create update]

    def initialize
      super
      @solr = RSolr.connect(url: Blacklight.connection_config[:url])
    end

    # get /datasets/<id>
    def show
      ds = Dataset.new(identifier: @stash_identifier.to_s, user: @user)
      respond_to do |format|
        format.any { render json: ds.metadata }
        res = @stash_identifier.latest_viewable_resource(user: @user)
        StashEngine::CounterLogger.general_hit(request: request, resource: res) if res
      end
    end

    # post /datasets
    def create
      respond_to do |format|
        format.any do
          dp = DatasetParser.new(hash: params['dataset'], id: nil, user: @user)
          @stash_identifier = dp.parse
          ds = Dataset.new(identifier: @stash_identifier.to_s, user: @user) # sets up display objects
          render json: ds.metadata, status: 201
        end
      end
    end

    # post /em_submission_metadata
    def em_submission_metadata
      # The Editorial Manager API sends metadata that is largely similar to our normal API, but it needs to be
      # reformatted before and after the normal processing.
      respond_to do |format|
        format.any do
          if @stash_identifier&.first_submitted_resource.present?
            # Once the dataset has been submitted by an author, only update selected fields,
            # but don't fully process the metadata from EM
            em_response = em_update_selected_fields
            status_code = em_response[:status] == 'Success' ? 200 : 403
            render json: em_response, status: status_code
          else
            dp = if @resource
                   DatasetParser.new(hash: em_reformat_request, id: @resource.identifier, user: @user)
                 else
                   DatasetParser.new(hash: em_reformat_request, id: nil, user: @user)
                 end
            @stash_identifier = dp.parse

            # By default, we select the peer review checkbox, since EM will be using the review URL
            @stash_identifier.latest_resource.update(hold_for_peer_review: true)

            ds = Dataset.new(identifier: @stash_identifier.to_s, user: @user) # sets up display objects
            render json: em_reformat_response(ds.metadata), status: 201
          end
        end
      end
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
    def em_update_selected_fields
      logger.debug('em_update_selected_fields')

      fields_changed = []
      art_params = params['article']

      # If manuscript number is available, update it
      manu = art_params['manuscript_number'] unless art_params.blank?
      if manu.present?
        datum = StashEngine::InternalDatum.where(stash_identifier: @stash_identifier, data_type: 'manuscriptNumber').first
        if datum.present?
          datum.update(value: manu)
        else
          StashEngine::InternalDatum.create(stash_identifier: @stash_identifier, data_type: 'manuscriptNumber', value: manu)
        end
        fields_changed << 'Manuscript Number'
      end

      # Add funding info if it was not added by the submitter
      if @resource.contributors.blank? && art_params['funding_information'].present?
        art_params['funding_information'].each do |f|
          @resource.contributors << StashDatacite::Contributor.create(contributor_name: f['funder'],
                                                                      contributor_type: 'funder', award_number: f['award_number'])
        end
        fields_changed << 'Funders'
      end

      # Add keywords if they were not added by the submitter
      if @resource.subjects.blank? && art_params['keywords'].present?
        @resource.subjects.clear
        art_params['keywords'].each do |kw|
          subs = StashDatacite::Subject.where(subject: kw)
          sub = if subs.blank?
                  StashDatacite::Subject.create(subject: kw)
                else
                  subs.first
                end
          @resource.subjects << sub
        end
        fields_changed << 'Keywords'
      end

      # Update curation note about what was changed
      if fields_changed.present?
        @resource.curation_activities <<
          StashEngine::CurationActivity.create(user_id: @user.id,
                                               status: @resource.current_curation_status,
                                               note: "updating metadata based on API notification from Editorial Manager: #{fields_changed}")
      end

      # If final_disposition is available, update the status of this dataset
      disposition = params['article']['final_disposition']
      if disposition.present? && (@resource.current_curation_status == 'peer_review')
        if disposition.downcase == 'accept'
          # article is accepted -> transition peer_review to curation
          @resource.curation_activities <<
            StashEngine::CurationActivity.create(user_id: @user.id, status: 'curation',
                                                 note: 'updating status based on API notification from Editorial Manager')
        else
          # any other article disposition -> transition peer_review to action_required
          @resource.curation_activities <<
            StashEngine::CurationActivity.create(user_id: @user.id, status: 'action_required',
                                                 note: 'updating status based on API notification from Editorial Manager')
        end
      end

      sharing_link = @stash_identifier&.shares&.first&.sharing_link ||
                     "/api/v2/datasets/#{CGI.escape(@stash_identifier.to_s)}"
      {
        deposit_id: @stash_identifier.identifier,
        deposit_doi: @stash_identifier.identifier,
        deposit_url: sharing_link,
        deposit_edit_url: "#{request.protocol}#{request.host_with_port}" \
                          "/stash/edit/#{CGI.escape(@stash_identifier.to_s)}/#{@stash_identifier&.edit_code}",
        status: 'Success'
      }
    end

    # Reformat a request from Editorial Manager's Submission call, enabling it to conform to our normal API.
    def em_reformat_request
      em_params = {}.with_indifferent_access

      # EM doesn't set an item owner, so default it to system, and the actual user will need to claim it
      em_params['userId'] = 0

      em_params['publicationName'] = params['journal_full_title']
      art_params = params['article']
      if art_params
        if art_params['article_doi']
          em_params['relatedWorks'] = []
          em_params['relatedWorks'] << {
            relationship: 'article',
            identifierType: 'DOI',
            identifier: art_params['article_doi']
          }.with_indifferent_access
        end
        em_params['manuscriptNumber'] = art_params['manuscript_number']
        em_params['title'] = art_params['article_title']
        em_params['abstract'] = art_params['abstract']
        keywords = [art_params['keywords'], art_params['classifications']].flatten.compact
        em_params['keywords'] = keywords if keywords
        if art_params['funding_information']
          em_funders = []
          art_params['funding_information'].each do |f|
            em_funders << {
              organization: f['funder'],
              awardNumber: f['award_number']
            }
          end
          em_params['funders'] = em_funders
        end
      end
      em_params['title'] = params['deposit_data']['deposit_description'] if params['deposit_data']
      em_params['manuscriptNumber'] ||= params['document_id'] || 'EM-DEPOSIT'

      em_authors = []
      auth_array = params['authors'] || params['author']
      if auth_array.is_a?(Array)
        auth_array.each do |auth|
          em_authors << {
            firstName: auth['first_name'],
            lastName: auth['last_name'],
            email: auth['email'],
            orcid: auth['orcid'],
            affiliation: auth['institution']
          }.with_indifferent_access.compact
        end
      else
        # assume there is only one author, so the param is an author hash
        auth = auth_array
        em_authors << {
          firstName: auth['first_name'],
          lastName: auth['last_name'],
          email: auth['email'],
          orcid: auth['orcid'],
          affiliation: auth['institution']
        }.with_indifferent_access.compact
      end
      em_params['authors'] = em_authors if em_authors.present?
      em_params
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity

    # Reformat a `metadata` response object, putting it in the format that Editorial Manager prefers
    def em_reformat_response(metadata)
      sharing_link = @stash_identifier.shares&.first&.sharing_link
      edit_url = (request.protocol + request.host_with_port + metadata[:editLink] if metadata[:editLink])
      {
        deposit_id: @stash_identifier.identifier,
        deposit_doi: @stash_identifier.identifier,
        deposit_url: sharing_link,
        deposit_edit_url: edit_url,
        deposit_upload_url: edit_url,
        status: 'Success'
      }.compact
    end

    # get /datasets
    def index
      ds_query = StashEngine::Identifier.user_viewable(user: @user) # this limits to a user's list based on their role/permissions (or public ones)
      # These filter conditions were things Daisie put in, because of some queries she needed to make.
      # We probably want to think about the query interface before we do full blown filtering and be sure it is thought out
      # and we are ready to support whatever we decide.

      # if a publicationISSN or manuscriptNumber is specified,
      # we want to make sure that we're only working those specified.
      if params.key?('publicationISSN')
        # add these conditions to narrow to publicationISSN
        ds_query = ds_query
          .joins('INNER JOIN stash_engine_internal_data ON stash_engine_identifiers.id = stash_engine_internal_data.identifier_id')
          .where("stash_engine_internal_data.data_type = 'publicationISSN' AND stash_engine_internal_data.value = ?", params['publicationISSN'])
      elsif params.key?('manuscriptNumber')
        # add these conditions to narrow to manuscriptNumber
        ds_query = ds_query
          .joins('INNER JOIN stash_engine_internal_data ON stash_engine_identifiers.id = stash_engine_internal_data.identifier_id')
          .where("stash_engine_internal_data.data_type = 'manuscriptNumber' AND stash_engine_internal_data.value = ?", params['manuscriptNumber'])
      end

      # now, if a curationStatus is specified, narrow down the previous result more.
      if params.key?('curationStatus')
        ds_query = ds_query.with_visibility(states: params['curationStatus']) # this finds identifiers with a version with this state, acceptable?
      end

      datasets = paged_datasets(datasets: ds_query)
      render json: datasets
    end

    # get /search
    def search
      # datasets in SOLR are always public, so there is no need to limit the query based on the API user
      page = params['page'] || 1
      per_page = [params['per_page']&.to_i || DEFAULT_PAGE_SIZE, 100].min
      query = params['q']

      begin
        solr_call = @solr.paginate(page, per_page, 'select',
                                   params: { q: query.to_s, fq: solr_filter_query, fl: 'dc_identifier_s' })
        solr_response = solr_call['response']

        # once we have the solr_response, use the DOIs to build the 'real' response
        mapped_results = solr_response['docs'].map { |i| Dataset.new(identifier: (i['dc_identifier_s']).to_s, user: @user).metadata }
        datasets = paging_hash_results(all_count: solr_response['numFound'],
                                       page_size: per_page,
                                       results: mapped_results)
        render json: datasets
      rescue RSolr::Error::Http
        render status: 400, plain: 'Unable to parse query request.'
      end
    end

    # Builds an array of the various filter settings requested
    def solr_filter_query
      fq_array = []

      # if user requests both 'affiliation' and 'tenant', prefer the affiliation,
      # because it is more specific
      if params['affiliation']
        # ["dryad_author_affiliation_id_sm:\"https://ror.org/01sf06y89\" "
        fq_array << "dryad_author_affiliation_id_sm:\"#{params['affiliation']}\" "
      elsif params['tenant']
        # multiple affiliations, separated by OR
        tenant = StashEngine::Tenant.find(params['tenant'])
        if tenant
          ror_array = []
          tenant.ror_ids.each do |r|
            # map the id into the format
            ror_array << "dryad_author_affiliation_id_sm:\"#{r}\" "
          end
          fq_array << ror_array.join(' OR ')
        else
          fq_array << 'dryad_author_affiliation_id_sm:"missing_tenant" '
        end
      end

      if params['modifiedSince']
        # ["timestamp:[2020-10-08T10:24:53Z TO NOW]"]
        fq_array << "timestamp:[#{params['modifiedSince']} TO NOW]"
      end

      fq_array
    end

    # we are using PATCH only to allow updates for a few status settings:
    # - versionStatus=submitted
    # - curationStatus
    # - publicationISSN
    # PUT will be to update/replace the dataset metadata
    # put/patch /datasets/<id>
    # we are also allowing UPSERT with a PUT as in the pattern at
    # https://www.safaribooksonline.com/library/view/restful-web-services/9780596809140/ch01s09.html or
    # https://stackoverflow.com/questions/18470588/in-rest-is-post-or-put-best-suited-for-upsert-operation
    def update
      do_patch { return } # check if patch and do operation, then return early if it is a patch
      # otherwise this is a PUT of the dataset metadata
      check_status { return } # check it's in progress, clone a submitted or raise an error
      respond_to do |format|
        format.any do
          dp = if @resource
                 DatasetParser.new(hash: params['dataset'], id: @resource.identifier, user: @user) # update dataset
               else
                 DatasetParser.new(hash: params['dataset'], user: @user, id_string: params[:id]) # upsert dataset with identifier
               end
          @stash_identifier = dp.parse
          ds = Dataset.new(identifier: @stash_identifier.to_s, user: @user) # sets up display objects
          render json: ds.metadata, status: 200
        end
      end
    end

    # get /datasets/<id>/download
    def download
      res = @stash_identifier.latest_downloadable_resource(user: @user)
      @version_presigned = Stash::Download::VersionPresigned.new(resource: res)
      if res&.may_download?(ui_user: @user) && @version_presigned.valid_resource?
        @status_hash = @version_presigned.download
        case @status_hash[:status]
        when 200
          StashEngine::CounterLogger.version_download_hit(request: request, resource: res)
          redirect_to @status_hash[:url]
        when 202
          render status: 202, plain: 'The version of the dataset is being assembled. ' \
          "Check back in around #{time_ago_in_words(res.download_token.available + 30.seconds)} and it should be ready to download."
        else
          render status: 404, plain: 'Not found'
        end
      else
        render plain: 'download for this version of the dataset is unavailable', status: 404
      end
    end

    # rubocop:disable Layout/LineLength
    # post /datasets/<id>/set_internal_datum
    def set_internal_datum
      if StashEngine::InternalDatum.allows_multiple(params[:data_type])
        render json: { error: "#{params[:data_type]} allows multiple entries, use add_internal_datum" }.to_json, status: 404
        nil
      else
        @datum = StashEngine::InternalDatum.where(data_type: params[:data_type], identifier_id: @stash_identifier.id).first
        @datum = StashEngine::InternalDatum.create(data_type: params[:data_type], stash_identifier: @stash_identifier, value: params[:value]) if @datum.nil?
        @datum.update!(value: params[:value])
        render json: @datum, status: 200
      end
    end

    # post /datasets/<id>/add_internal_datum
    def add_internal_datum
      unless StashEngine::InternalDatum.allows_multiple(params[:data_type])
        render json: { error: "#{params[:data_type]} does not allow multiple entries, use set_internal_datum" }.to_json, status: 404
        return
      end
      @datum = StashEngine::InternalDatum.create(data_type: params[:data_type], stash_identifier: @stash_identifier, value: params[:value])
      render json: @datum, status: 200
    end
    # rubocop:enable Layout/LineLength

    def get_stash_identifier(id)
      return nil if id.blank?
      # check to see if the identifier is actually an id and not a DOI first
      return StashEngine::Identifier.where(id: id).first if id.match?(/^\d+$/)

      if id.include?(':')
        id_type, id_text = id.split(':', 2)
      else
        # assume it's a DOI, without the prefix
        id_type = 'DOI'
        id_text = id
      end
      render json: { error: 'incorrect DOI format' }.to_json, status: 404 if !id_type.casecmp('DOI').zero? || !id_text.match(%r{^10\.\S+/\S+$})
      StashEngine::Identifier.where(identifier_type: id_type.upcase).where(identifier: id_text).first
    end

    def initialize_stash_identifier(id)
      @stash_identifier = get_stash_identifier(id)
      render json: { error: "cannot find dataset with identifier #{id}" }.to_json, status: 404 if @stash_identifier.blank?
    end

    private

    def setup_identifier_and_resource_for_put
      @stash_identifier = get_stash_identifier(params[:id]) || get_stash_identifier(params[:deposit_id])
      @resource = @stash_identifier.resources.by_version_desc.first unless @stash_identifier.blank?
    end

    def do_patch
      content_type = request.headers['content-type']
      return unless request.method == 'PATCH' && content_type.present? && content_type.start_with?('application/json-patch+json')

      check_patch_prerequisites { yield }
      check_dataset_completions { yield }
      @resource.send_software_to_zenodo # this only does anything if software needs to be sent (new sfw or sfw in the past)
      @resource.send_supp_to_zenodo

      case @json.first['path']
      when '/versionStatus'
        ensure_in_progress { yield }
        pre_submission_updates
        StashEngine.repository.submit(resource_id: @resource.id)
        ds = Dataset.new(identifier: @stash_identifier.to_s, user: @user)
        render json: ds.metadata, status: 202
      when '/curationStatus'
        update_curation_status(@json.first['value'])
        render json: @resource.reload.current_curation_activity
      when '/publicationISSN'
        update_publication_issn(@json.first['value'])
        render json: @resource.reload.current_curation_activity
      else
        return_error(messages: "Operation not supported: #{@json.first['path']}", status: 400) { yield }
      end
      yield
    end

    def update_curation_status(new_status)
      note = 'status updated via API call'

      # DON'T go backwards in workflow,
      # that is, don't change a status other than submitted or peer_review
      unless %w[submitted peer_review].include?(@resource.current_curation_status)
        note = "received API request to change status to #{new_status}, but retaining current curation status due to workflow rules"
        new_status = @resource.current_curation_status
      end

      StashEngine::CurationActivity.create(resource_id: @resource.id,
                                           user_id: @user.id,
                                           status: new_status,
                                           note: note)
    end

    def update_publication_issn(new_issn)
      datum = StashEngine::InternalDatum.where(identifier_id: @stash_identifier.id, data_type: 'publicationISSN').first
      if new_issn.present?
        # real value, update an existing value or create a new one
        if datum
          datum.update(value: new_issn)
        else
          StashEngine::InternalDatum.create(identifier_id: @stash_identifier.id,
                                            data_type: 'publicationISSN',
                                            value: new_issn)
        end
      else
        # nil/empty new_issn, remove any existing datum
        datum&.destroy
      end
    end

    # checks the status for allowing a dataset PUT request that is an update
    def check_status
      return if @stash_identifier.nil? || @resource.nil?

      state = @resource.current_resource_state.try(:resource_state)
      return if state == 'in_progress'

      return_error(messages: 'Your dataset cannot be updated now', status: 403) { yield } if state != 'submitted'
      duplicate_resource # because we're starting a new version
    end

    # some parameters would be locked down for only admins or superusers to set
    def lock_down_admin_only_params
      # all this bogus return false stuff is to prevent double render errors in some circumstances
      return if check_superuser_restricted_params == false
      return if check_may_set_user_id == false
      return if check_may_set_payment_id == false
    end

    def check_superuser_restricted_params
      %w[skipDataciteUpdate skipEmails preserveCurationStatus loosenValidation].each do |attr|
        item_value = params[attr]
        unless item_value.nil? || item_value.class == TrueClass || item_value.class == FalseClass
          render json: { error: "Bad Request: #{attr} must be true or false" }.to_json, status: 400
          return false
        end
        if item_value.class == TrueClass && @user.role != 'superuser'
          render json: { error: "Unauthorized: only superusers may set #{attr} to true" }.to_json, status: 401
          return false
        end
      end
    end

    def check_may_set_user_id
      return if params['userId'].nil?

      unless @user.role == 'superuser' ||
             params['userId'].to_i == @user.id || # or it is your own user
             @user.journals_as_admin&.map(&:issn)&.include?(params['dataset']['publicationISSN']) # or you admin the target journal
        render json: { error: 'Unauthorized: only superusers and journal administrators may set a specific user' }.to_json, status: 401
        false
      end
    end

    def check_may_set_payment_id
      return if params['paymentId'].nil?

      unless @user.role == 'superuser'
        render json: { error: 'Unauthorized: only superuser roles may set a paymentId' }.to_json, status: 401
        return false
      end
      false
    end

    def duplicate_resource
      nr = @resource.amoeba_dup
      nr.current_editor_id = @user.id
      nr.save!
      @resource = nr
    end

    def paged_datasets(datasets:, page_size: DEFAULT_PAGE_SIZE)
      all_count = datasets.count
      results = datasets.limit(page_size).offset(page_size * (page - 1))
      mapped_results = results.map { |i| Dataset.new(identifier: "#{i.identifier_type}:#{i.identifier}", user: @user).metadata }
      paging_hash_results(all_count: all_count, page_size: page_size, results: mapped_results)
    end

    def paging_hash_results(all_count:, page_size:, results:)
      return if results.nil?

      {
        '_links' => paging_hash(result_count: all_count, page_size: page_size),
        count: results.count,
        total: all_count,
        '_embedded' => { 'stash:datasets' => results }
      }
    end

  end
end

# rubocop:enable Metrics/ClassLength
