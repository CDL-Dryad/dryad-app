require 'datacite/mapping'
require 'stash_ezid/client'

module StashDatacite
  class TestImport

    def initialize(
        user_uid='scott.fisher-ucb@ucop.edu',
        xml_filename=File.join(StashDatacite::Engine.root, 'test', 'fixtures', 'datacite-example-full-v3.1.xml'),
        ezid_shoulder="doi:10.5072/FK2",
        ezid_account="apitest",
        ezid_password="apitest"
        )
      @user = StashEngine::User.find_by_uid(user_uid)
      @xml_str = File.read(xml_filename)
      @m_resource = Datacite::Mapping::Resource.parse_xml(@xml_str)
      @ezid_client = StashEzid::Client.new(
                  { shoulder:   ezid_shoulder,
                    account:    ezid_account,
                    password:   ezid_password,
                    coowners:   [''],
                    id_scheme: 'doi'
                  })
    end

    def datacite_mapping
      @m_resource
    end

    def populate_tables

      set_up_resource
      #TODO: also need to add additional values to resource: geolocation (0/1), download_uri, update_uri

      add_creators
      add_titles
      add_publisher
      add_publication_year
      add_subjects
      add_contributors
      add_dates
      add_language
      add_resource_type
      add_alternate_identifiers
      add_related_identifiers
      add_sizes
      add_formats
      add_version
      add_rights
      add_descriptions
      add_geolocations
    end

    def set_up_resource
      #get a new ezid id ready and create identifier in DB
      minted_id = @ezid_client.mint_id # retured like "doi:10.5072/FK2NK3C276"
      ezid_id_type, ezid_id_body = minted_id.split(':', 2)
      ezid_id_type.upcase!
      stash_id = StashEngine::Identifier.create(identifier: ezid_id_body, identifier_type: ezid_id_type)

      # create resource with resource_state, identifier (DOI) and version for a user
      @resource = StashEngine::Resource.create(user_id: @user.id, identifier_id: stash_id.id)
      resource_state = StashEngine::ResourceState.create(user_id: @user.id, resource_state: 'submitted', resource_id: @resource.id)
      @resource.update(current_resource_state_id: resource_state.id)
      StashEngine::Version.create(version: 1, resource_id: @resource.id)
    end

    def add_creators
      @m_resource.creators.each do |c|
        lname, fname = extract_last_first(c.name)
        affils = Affliation.where("short_name = ? or long_name = ?", c.affiliations.try(:first), c.affiliations.try(:first))
        affil_no = nil
        if affils.blank?
          affil_no = Affliation.create(long_name: c.affiliations.first ).id if c.affiliations.length > 0
        else
          affil_no = affils.first.id
        end
        name_identifier_id = nil
        orcid_id = nil
        unless c.try(:identifier).blank?
          if c.identifier.scheme == 'ORCID'
            orcid_id = c.identifier.value unless c.identifier.value.blank?
          else
            name_id = NameIdentifier.find_or_create_by(name_identifier: c.identifier.value) do |ni|
              ni.scheme = c.identifier.scheme
              ni.scheme_uri = c.identifier.scheme_uri
            end
            name_identifier_id = name_id.id
          end
        end

        Creator.create(
            creator_first_name:   fname,
            creator_last_name:    lname,
            name_identifier_id:   name_identifier_id,
            orcid_id:             orcid_id,
            resource_id:          @resource.id,
            affliation_id:        affil_no
        )
      end
    end

    def add_titles
      @m_resource.titles.each do |t|
        title_type = 'main'
        unless t.type.nil?
          title_type = t.type.value.downcase
        end
        Title.create(title: t.value, title_type: title_type, resource_id: @resource.id)
      end
    end

    def add_publisher
      unless @m_resource.publisher.blank?
        Publisher.create(publisher: @m_resource.publisher, resource_id: @resource.id)
      end
    end

    def add_publication_year
      unless @m_resource.publication_year.blank?
        PublicationYear.create(publication_year: @m_resource.publication_year, resource_id: @resource.id)
      end
    end

    def add_subjects

    end

    def add_contributors

    end

    def add_dates
      @m_resource.dates.each do |d|
        Dates.create(date: d.value, date_type: d.type.value.downcase)
      end
    end

    def add_language
      # TODO: We don't seem to have a language in the database
      #unless @m_resource.language.blank?
      #
      #end
    end

    def add_resource_type
      unless @m_resource.resource_type.blank?
        ResourceType.create(resource_type: @m_resource.resource_type.try(:resource_type_general).try(:value),
                            resource_id: @resource.id)
      end
    end

    def add_alternate_identifiers

    end

    def add_related_identifiers

    end

    def add_sizes
      @m_resource.sizes.each do |s|
        Size.create(size: s, resource_id: @resource.id)
      end
    end

    def add_formats
      # TODO: formats seems to be missing from database
    end

    def add_version
      unless @m_resource.version.blank?
        Version.create(version: @m_resource.version)
      end
    end

    def add_rights
      @m_resource.rights_list.each do |r|
        Rights.create(rights: r.value , rights_uri: r.uri)
      end
    end

    def add_descriptions
      @m_resource.descriptions.each do |d|
        Description.create(description: d.value, description_type: d.type.value.downcase, resource_id: @resource.id)
      end
    end

    def add_geolocations

    end


    private
    def extract_last_first(name_w_comma)
      name_w_comma.split(',', 2).map{|i| i.strip}
    end
  end
end
