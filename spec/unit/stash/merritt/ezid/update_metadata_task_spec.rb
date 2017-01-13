require 'spec_helper'
require 'ostruct'

module Stash
  module Merritt
    module Ezid
      describe UpdateMetadataTask do
        attr_reader :resource_id
        attr_reader :resource
        attr_reader :task
        attr_reader :tenant
        attr_reader :url_helpers

        before(:each) do
          @resource_id = 17
          @resource    = double(StashEngine::Resource)
          allow(StashEngine::Resource).to receive(:find).with(resource_id).and_return(resource)

          @tenant   = double(StashEngine::Tenant)
          id_params = {
            shoulder:  'doi:10.15146/R3',
            account:   'stash',
            owner: 'stash_admin',
            password:  '3cc9d3fbd9788148c6a32a1415fa673a',
            id_scheme: 'doi'
          }
          allow(tenant).to receive(:identifier_service).and_return(OpenStruct.new(id_params))

          @url_helpers = double(Module)
          @task = UpdateMetadataTask.new(resource_id: resource_id, tenant: tenant, url_helpers: url_helpers)
        end

        describe :exec do
          it 'updates the metadata and landing page' do
            identifier_str = 'doi:10.15146/R38675309'
            allow(resource).to receive(:identifier_str).and_return(identifier_str)

            datacite_xml = '<resource/>'
            package = instance_double(Stash::Merritt::Package::SubmissionPackage)
            expect(package).to receive(:dc3_xml).and_return(datacite_xml)

            landing_page_url = "http://stash.example.edu/stash/#{identifier_str}"
            expect(url_helpers).to receive(:show_path).with(identifier_str).and_return(landing_page_url)

            ezid_client = instance_double(::Ezid::Client)
            allow(::Ezid::Client).to receive(:new)
              .with(user: 'stash', password: '3cc9d3fbd9788148c6a32a1415fa673a')
              .and_return(ezid_client)

            expect(ezid_client).to receive(:modify_identifier).with(
              identifier_str,
              datacite: datacite_xml,
              target: landing_page_url,
              status: 'public',
              owner: 'stash_admin'
            )

            expect(task.exec(package)).to eq(package)
          end
        end
      end
    end
  end
end
