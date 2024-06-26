# frozen_string_literal: true

# This is NOT an ActiveRecord model and does not persist data!!
# This class represents a row in the Admin's Curation page. It only retrieves the information
# necessary to populate the table on that page.
#
# Use like
# @datasets = StashEngine::AdminDatasets::CurationTableRow.where(params: helpers.sortable_table_params, tenant: tenant_limit) # (gets all results)
#
# If you want to get just one identifier for redrawing a single row, something like this should work
# @dataset = StashEngine::AdminDatasets::CurationTableRow.where(params: {}, tenant: nil, identifier_id: 37575).first
module StashEngine
  module AdminDatasets
    class CurationTableRow

      attr_reader :publication_name, :identifier_id, :identifier, :qualified_identifier, :resource_size,
                  :search_words, :resource_id, :title, :created_date, :publication_date, :tenant_id, :resource_state_id,
                  :resource_state, :curation_activity_id, :status, :updated_at, :submission_date, :editor_id, :editor_name,
                  :author_names, :views, :downloads, :citations, :relevance

      SELECT_CLAUSE = <<-SQL
        SELECT DISTINCT seid.value,
          sei.id, sei.identifier, CONCAT(LOWER(sei.identifier_type), ':', sei.identifier), ser.total_file_size, sei.search_words,
          ser.id, ser.title, sei.created_at, ser.publication_date, ser.tenant_id,
          sers.id, sers.resource_state,
          seca.id, seca.status, seca.updated_at, sd.submission_date,
          seu.id, seu.last_name, seu.first_name,
          (SELECT GROUP_CONCAT(DISTINCT sea.author_last_name ORDER BY sea.author_last_name SEPARATOR '; ')
           FROM stash_engine_authors sea
           WHERE sea.resource_id = ser.id),
          secs.unique_investigation_count, secs.unique_request_count, secs.citation_count
      SQL

      FROM_CLAUSE = <<-SQL
          FROM stash_engine_identifiers sei
          INNER JOIN stash_engine_resources ser ON sei.latest_resource_id = ser.id
          LEFT OUTER JOIN stash_engine_internal_data seid ON sei.id = seid.identifier_id AND seid.data_type = 'publicationName'
          LEFT OUTER JOIN stash_engine_users seu ON ser.current_editor_id = seu.id
          LEFT OUTER JOIN (SELECT rs2.resource_id, MAX(rs2.id) latest_resource_state_id FROM stash_engine_resource_states rs2 GROUP BY rs2.resource_id) j2 ON j2.resource_id = ser.id
          LEFT OUTER JOIN stash_engine_resource_states sers ON sers.id = j2.latest_resource_state_id
          LEFT OUTER JOIN stash_engine_curation_activities seca ON seca.id = ser.last_curation_activity_id
          LEFT OUTER JOIN stash_engine_counter_stats secs ON sei.id = secs.identifier_id
          LEFT OUTER JOIN dcs_contributors dcs_c ON ser.id = dcs_c.resource_id
          LEFT OUTER JOIN (SELECT DISTINCT sei.id, min(subcur.created_at) submission_date
            FROM stash_engine_identifiers sei
            RIGHT OUTER JOIN stash_engine_resources subser on sei.id = subser.identifier_id
            RIGHT OUTER JOIN stash_engine_curation_activities subcur on subser.id = subcur.resource_id
            WHERE subcur.status in ('submitted', 'peer-review')
            group by sei.id
          ) sd on sd.id = sei.id
      SQL

      # add extra joins when I need to reach into author affiliations for every dataset
      FROM_CLAUSE_ADMIN = <<-SQL.freeze
        #{FROM_CLAUSE}
        LEFT OUTER JOIN stash_engine_authors sea2 ON ser.id = sea2.resource_id
        LEFT OUTER JOIN dcs_affiliations_authors dcs_aa ON sea2.id = dcs_aa.author_id
        LEFT OUTER JOIN dcs_affiliations dcs_a ON dcs_aa.affiliation_id = dcs_a.id
      SQL

      SEARCH_CLAUSE = 'MATCH(sei.search_words) AGAINST(%{term})'
      BOOLEAN_SEARCH_CLAUSE = 'MATCH(sei.search_words) AGAINST(%{term} IN BOOLEAN MODE)'
      SCAN_CLAUSE = 'sei.search_words LIKE %{term}'
      TENANT_CLAUSE = 'ser.tenant_id = %{term}'
      STATUS_CLAUSE = 'seca.status = %{term}'
      EDITOR_CLAUSE = 'ser.current_editor_id = %{term}'
      EDITOR_NULL = 'ser.current_editor_id is NULL'
      PUBLICATION_CLAUSE = 'seid.value = %{term}'
      IDENTIFIER_CLAUSE = 'sei.id = %{term}'

      # this method is long, but quite uncomplicated as it mostly just sets variables from the query
      #
      def initialize(result, curator_ids)
        return unless result.is_a?(Array) && result.length >= 23

        # Convert the array of results into attribute values
        @publication_name = result[0]
        @identifier_id = result[1]
        @identifier = result[2]
        @qualified_identifier = result[3]
        @resource_size = result[4]
        @search_words = result[5]
        @resource_id = result[6]
        @title = result[7]
        @created_date = result[8]
        @publication_date = result[9]
        @tenant_id = result[10]
        @resource_state_id = result[11]
        @resource_state = result[12]
        @curation_activity_id = result[13]
        @status = result[14]
        @updated_at = result[15]
        @submission_date = result[16]
        @editor_id = curator_ids.include?(result[17].to_i) ? result[17] : nil
        @editor_name = @editor_id ? "#{result[19]} #{result[18]}" : nil
        @author_names = result[20]
        @views = (result[22].nil? ? 0 : result[21] - result[22])
        @downloads = result[22] || 0
        @citations = result[23] || 0
        @relevance = result.length > 24 ? result[24] : nil
      end

      # lets you get a resource when you need it and caches it
      def resource
        @resource ||= StashEngine::Resource.find_by(id: @resource_id)
      end

      class << self

        # params are params from the form.
        # The tenant, if set, does two things in conjunction.  it limits to items with a tenant_id of the tenant OR
        # affiliated author institution RORs (may be multiple) for this tenant with additional joins and conditions.
        # tenant is only set for tenant admins (not superusers or curators).
        # The journals, if set, limits to items associated with one of the given journals.
        # The funders, if set, limits to items associated with one of the given funders.
        #
        # if resource_id is set then only returns that resource id
        # rubocop:disable Metrics/ParameterLists
        def where(params:, tenant: nil, journals: nil, funders: nil, identifier_id: nil, page: 1, page_size: 10)
          # If a search term was provided include the relevance score in the results for sorting purposes
          relevance = params.fetch(:q, '').blank? ? '' : ", (#{add_term_to_clause(SEARCH_CLAUSE, params.fetch(:q, ''))}) relevance"
          # editor_name is derived from 2 DB fields so use the last_name instead
          column = (params.fetch(:sort, '') == 'editor_name' ? 'last_name' : params.fetch(:sort, ''))

          query = " \
            #{SELECT_CLAUSE}
            #{relevance}
            #{tenant ? FROM_CLAUSE_ADMIN : FROM_CLAUSE}
            #{build_where_clause(search_term: params.fetch(:q, ''),
                                 all_advanced: params.fetch(:all_advanced, false),
                                 tenant_filter: params.fetch(:tenant, ''),
                                 status_filter: params.fetch(:curation_status, ''),
                                 editor_filter: params.fetch(:editor_id, ''),
                                 publication_filter: params.fetch(:publication_name, ''),
                                 sponsor_filter: params.fetch(:sponsor_org, ''),
                                 admin_tenant: tenant,
                                 admin_journals: journals,
                                 admin_funders: funders,
                                 identifier_id: identifier_id)}
            #{build_order_clause(column, params.fetch(:direction, ''), params.fetch(:q, ''))}
            #{build_limit_clause(page: page, page_size: page_size)}
          "
          curator_ids = StashEngine::User.curators.map(&:id)
          results = ApplicationRecord.connection.execute(query).map { |result| new(result, curator_ids) }
          # If the user is trying to sort by author names, then
          (column == 'author_names' ? sort_by_author_names(results, params.fetch(:direction, '')) : results)
        end
        # rubocop:enable Metrics/ParameterLists

        private

        # Create the WHERE portion of the query based on the filters set by the user (if any)
        # rubocop:disable Metrics/ParameterLists
        def build_where_clause(search_term:, all_advanced:, tenant_filter:, status_filter:, editor_filter:,
                               publication_filter:, sponsor_filter:, admin_tenant:, admin_journals:, admin_funders:,
                               identifier_id: nil)
          where_clause = [
            (search_term.present? ? build_search_clause(search_term, all_advanced) : nil),
            add_term_to_clause(TENANT_CLAUSE, tenant_filter),
            add_term_to_clause(STATUS_CLAUSE, status_filter),
            editor_filter == 'NA' ? EDITOR_NULL : add_term_to_clause(EDITOR_CLAUSE, editor_filter),
            add_term_to_clause(PUBLICATION_CLAUSE, publication_filter),
            add_term_to_clause(IDENTIFIER_CLAUSE, identifier_id),
            create_tenant_limit(admin_tenant),
            create_journals_limit(admin_journals),
            create_sponsor_limit(sponsor_filter),
            create_funders_limit(admin_funders)
          ].compact
          where_clause.empty? ? '' : " WHERE #{where_clause.join(' AND ')}"
        end
        # rubocop:enable Metrics/ParameterLists

        # Build the WHERE portion of the query for the specified search term (if any)
        def build_search_clause(term, all_advanced)
          return '' unless term.present?

          if all_advanced == '1'
            "(#{add_term_to_clause(BOOLEAN_SEARCH_CLAUSE, advanced_search(term))})"
          else
            "(#{add_term_to_clause(SEARCH_CLAUSE, term)})"
          end
        end

        # If someone is choosing 'all words' then default to boolean search and determine if they're using common
        # modifiers, and if so just pass it through because they are likely a special person who knows what they're doing,
        # otherwise add plusses to all their words to make them required internally
        def advanced_search(terms)
          if /[~+<>*]/.match?(terms)
            terms
          else
            terms&.split&.map { |i| "+\"#{i}\"" }&.join(' ')
          end
        end

        # Create the ORDER BY portion of the query. If the user included a search term order by relevance first!
        # We cannot sort by author_names here, so ignore if that is the :sort_column
        def build_order_clause(column, direction, q)
          return 'ORDER BY title' if column == 'relevance' && q.blank?

          if column == 'relevance'
            'ORDER BY relevance DESC'
          else
            (column.present? && column != 'author_names' ? "ORDER BY #{column} #{direction || 'ASC'}" : '')
          end
        end

        def build_limit_clause(page:, page_size:)
          # rows start at 0 and limit is offset, row_count.  I multiply page size so we know if there are a few pages afterward
          # LIMIT [offset,] row_count;
          " LIMIT #{(page - 1) * page_size}, #{page_size * 4}"
        end

        def sort_by_author_names(results, direction)
          multiply_by = (direction.casecmp('desc').zero? ? -1 : 1)
          results.sort { |a, b| multiply_by * ((a&.author_names&.downcase || '') <=> (b&.author_names&.downcase || '')) }
        end

        # Swap a term into the SQL snippet/clause
        def add_term_to_clause(clause, term)
          return nil unless clause.present? && term.present?

          format(clause.to_s, term: ActiveRecord::Base.connection.quote(term))
        end

        def create_tenant_limit(admin_tenant)
          return nil if admin_tenant.blank?

          ActiveRecord::Base.send(:sanitize_sql_array, ['( ser.tenant_id = ? OR dcs_a.ror_id IN (?) )', admin_tenant.tenant_id,
                                                        admin_tenant.ror_ids])
        end

        def create_journals_limit(admin_journals)
          return nil if admin_journals.blank?

          ActiveRecord::Base.send(:sanitize_sql_array, ['( seid.value IN (?) )', admin_journals])
        end

        def create_sponsor_limit(sponsor_filter)
          return nil if sponsor_filter.blank?

          sponsor_org = StashEngine::JournalOrganization.find(sponsor_filter)
          admin_journals = sponsor_org.journals_sponsored.map(&:title)
          ActiveRecord::Base.send(:sanitize_sql_array, ['( seid.value IN (?) )', admin_journals])
        end

        def create_funders_limit(admin_funders)
          return nil if admin_funders.blank?

          ActiveRecord::Base.send(:sanitize_sql_array, ['( dcs_c.name_identifier_id IN (?) )', admin_funders])
        end

      end

    end
  end
end
