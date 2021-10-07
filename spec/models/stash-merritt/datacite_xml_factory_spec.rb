require 'stash/stash-merritt/lib/datacite/mapping/datacite_xml_factory'
require 'nokogiri'

module Datacite
  module Mapping
    describe DataciteXMLFactory do

      before(:each) do
        total_size_bytes = 3_286_679

        @dc4_xml = File.read('spec/data/archive/mrt-datacite.xml')
        @dcs_resource = Datacite::Mapping::Resource.parse_xml(@dc4_xml)

        user = create(:user,
                      first_name: 'Lisa',
                      last_name: 'Muckenhaupt',
                      email: 'lmuckenhaupt@example.edu',
                      tenant_id: 'dataone')

        @resource = create(:resource,
                           user: user,
                           tenant_id: 'dataone')

        @xml_factory = DataciteXMLFactory.new(
          se_resource_id: @resource.id,
          doi_value: @resource.identifier.identifier,
          total_size_bytes: total_size_bytes,
          version: 1
        )
      end

      it 'generates DC3' do
        # Should look like spec/data/dc3.xml
        actual_string = @xml_factory.build_datacite_xml(datacite_3: true)
        actual = Hash.from_xml(actual_string)['resource']

        expect(actual['xmlns']).to eq('http://datacite.org/schema/kernel-3')
        expect(actual['titles']['title']).to eq(@resource.title)
        expect(actual['identifier']).to eq(@resource.identifier.identifier)
        expect(actual['publicationYear']).to eq(@resource.publication_date.year.to_s)
        expect(actual['creators']['creator']['creatorName']).to eq(@resource.authors.first.author_full_name)
        expect(actual['creators']['creator']['nameIdentifier']).to eq(@resource.authors.first.author_orcid)
      end

      it 'generates DC4' do
        # Should look like spec/data/dc4-with-funding-references.xml
        actual_string = @xml_factory.build_datacite_xml
        actual = Hash.from_xml(actual_string)['resource']

        expect(actual['xmlns']).to eq('http://datacite.org/schema/kernel-4')
        expect(actual['titles']['title']).to eq(@resource.title)
        expect(actual['identifier']).to eq(@resource.identifier.identifier)
        expect(actual['publicationYear']).to eq(@resource.publication_date.year.to_s)
        expect(actual['creators']['creator']['creatorName']).to eq(@resource.authors.first.author_full_name)
        expect(actual['creators']['creator']['nameIdentifier']).to eq(@resource.authors.first.author_orcid)
      end

      it 'defaults missing resource_type to DATASET' do
        @resource.resource_type = nil
        @resource.save!

        dcs_resource = @xml_factory.build_resource
        resource_type = dcs_resource.resource_type
        expect(resource_type).not_to be_nil
        expect(resource_type.resource_type_general).to be(ResourceTypeGeneral::DATASET)
      end

      it 'creates FOS Science subject in the way DataCite requested' do
        subject = create(:subject, subject_scheme: 'fos')
        @resource.subjects << subject
        @resource.save!

        dcs_resource = @xml_factory.build_resource
        subjs = dcs_resource.subjects.map(&:value)
        expect(subjs).to include("FOS: #{subject.subject}")
      end

      it 'generates funders with funderIdentifiers if contributor has name_identifier_id' do
        contributor = create(:contributor, resource_id: @resource.id)
        dc_xml_string = @xml_factory.build_datacite_xml
        doc = Nokogiri::XML(dc_xml_string)
        doc.remove_namespaces! # to simplify the xpath expressions for convenience
        x_funder = doc.xpath('//resource/fundingReferences/fundingReference').first

        expect(x_funder.xpath('funderName').to_s).to include(contributor.contributor_name.encode(xml: :text))
        expect(x_funder.xpath('funderIdentifier').to_s).to include('funderIdentifierType="Crossref Funder ID"')
        expect(x_funder.xpath('funderIdentifier').to_s).to include(contributor.name_identifier_id.encode(xml: :text))
        expect(x_funder.xpath('awardNumber').to_s).to include(contributor.award_number.encode(xml: :text))
      end

      it 'leaves out funderIdentifier if contributor has blank name_identifier_id' do
        contributor = create(:contributor, resource_id: @resource.id, name_identifier_id: nil)
        dc_xml_string = @xml_factory.build_datacite_xml
        doc = Nokogiri::XML(dc_xml_string)
        doc.remove_namespaces! # to simplify the xpath expressions for convenience
        x_funder = doc.xpath('//resource/fundingReferences/fundingReference').first

        expect(x_funder.xpath('funderName').to_s).to include(contributor.contributor_name.encode(xml: :text))
        expect(x_funder.xpath('funderIdentifier').to_s).to be_blank
        expect(x_funder.xpath('awardNumber').to_s).to include(contributor.award_number.encode(xml: :text))
      end
    end
  end
end
