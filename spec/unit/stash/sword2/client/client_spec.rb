require 'spec_helper'
require 'webmock/rspec'

module Stash
  module Sword2
    describe Client do
      it 'can be instantiated' do
        client = Client.new(username: 'elvis', password: 'presley')
        expect(client).to be_a(Client)
      end

      attr_reader :username, :client, :password, :on_behalf_of, :zipfile, :slug

      before(:each) do
        @username = 'ucb_dash_submitter'
        @password = 'ucb_dash_password'
        @on_behalf_of = 'ucb_dash_author'
        @client = Client.new(username: @username, password: @password, on_behalf_of: @on_behalf_of)
        @zipfile = 'examples/uploads/example.zip'
        @slug = "doi:10.5072/FK#{Time.now.getutc.xmlschema.gsub(/[^0-9a-z]/i, '')}"
      end

      describe '#create' do
        it 'POSTs with the correct headers' do
          collection_uri = 'http://uc3-mrtsword-dev.cdlib.org:39001/mrtsword/collection/dash_ucb'
          authorized_uri = collection_uri.sub('http://', "http://#{username}:#{password}@")

          stub_request(:post, authorized_uri).to_return(
              body: '<entry xmlns="http://www.w3.org/2005/Atom"><id>http://merritt.cdlib.org/sword/v2/object/ark:/99999/fk4t157x4p</id><author><name>ucb_dash_submitter</name></author><generator uri="http://www.swordapp.org/" version="2.0" /><link href="http://merritt.cdlib.org/sword/v2/object/ark:/99999/fk4t157x4p" rel="edit" /><link href="http://merritt.cdlib.org/sword/v2/object/ark:/99999/fk4t157x4p" rel="http://purl.org/net/sword/terms/add" /><link href="http://merritt.cdlib.org/sword/v2/object/ark:/99999/fk4t157x4p" rel="edit-media" /><treatment xmlns="http://purl.org/net/sword/terms/">no treatment information available</treatment></entry>'
          )

          client.create(collection_uri: collection_uri, zipfile: zipfile, slug: slug)

          md5 = Digest::MD5.file(zipfile).to_s

          actual_headers = nil
          expect(a_request(:post, authorized_uri).with do |req|
            actual_headers = req.headers
          end).to have_been_made

          aggregate_failures('request headers') do
            {
                'On-Behalf-Of' => on_behalf_of,
                'Packaging' => 'http://purl.org/net/sword/package/SimpleZip',
                'Slug' => slug,
                'Content-Disposition' => 'attachment; filename=example.zip',
                'Content-MD5' => md5,
                'Content-Length' => /[0-9]+/,
                'Content-Type' => 'application/zip'
            }.each do |k, v|
              expect(actual_headers).to include_header(k, v)
            end
          end
        end

        it 'does something clever and asynchronous'
        it 'forwards a success response'
        it 'forwards a 4xx error'
        it 'forwards a 5xx error'
      end

      describe '#update' do
        it 'PUTs with the correct headers' do
          edit_iri = "http://merritt.cdlib.org/sword/v2/object/#{slug}"
          authorized_uri = edit_iri.sub('http://', "http://#{username}:#{password}@")

          stub_request(:put, authorized_uri)

          client.update(edit_iri: edit_iri, slug: slug, zipfile: zipfile)

          md5 = Digest::MD5.file(zipfile).to_s

          actual_body = nil
          actual_headers = nil
          expect(a_request(:put, authorized_uri).with do |req|
            actual_body = req.body
            actual_headers = req.headers
          end).to have_been_made

          aggregate_failures('request headers') do
            {
                'Content-Length' => /[0-9]+/,
                'Content-Type' => %r{multipart/related; type="application/atom\+xml"; boundary=.*},
                'On-Behalf-Of' => on_behalf_of
            }.each do |k, v|
              expect(actual_headers).to include_header(k, v)
            end
          end

          mime_headers = {
              'Packaging' => 'http://purl.org/net/sword/package/SimpleZip',
              'Content-Disposition' => 'attachment; name="payload"; filename="example.zip"',
              'Content-Type' => 'application/zip',
              'Content-MD5' => md5
          }

          aggregate_failures('MIME headers') do
            mime_headers.each do |k, v|
              expect(actual_body).to include("#{k}: #{v}")
            end
          end
        end

        it 'does something clever and asynchronous'
        it 'forwards a success response'
        it 'forwards a 4xx error'
        it 'forwards a 5xx error'
      end

    end
  end
end
