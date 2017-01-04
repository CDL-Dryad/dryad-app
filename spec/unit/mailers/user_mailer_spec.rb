require 'spec_helper'

module StashEngine
  describe UserMailer do
    attr_reader :title
    attr_reader :doi
    attr_reader :doi_value
    attr_reader :request_host
    attr_reader :request_port
    attr_reader :user
    attr_reader :resource
    attr_reader :mailer
    attr_reader :tenant
    attr_reader :sender_address
    attr_reader :feedback_address

    before(:each) do
      @title = 'An Account of a Very Odd Monstrous Calf'
      @doi_value = '10.1098/rstl.1665.0007'
      @doi = "doi:#{doi_value}"
      @request_host = 'stash.example.org'
      @request_port = 80

      @tenant = double(Tenant)
      allow(tenant).to receive(:contact_email).and_return(%w(contact1@example.edu contact2@example.edu))

      @user = double(User)
      allow(user).to receive(:first_name).and_return('Jane')
      allow(user).to receive(:last_name).and_return('Doe')
      allow(user).to receive(:email).and_return('jane.doe@example.edu')
      allow(user).to receive(:tenant).and_return(tenant)

      @resource = double(Resource)
      allow(resource).to receive(:user).and_return(user)
      allow(resource).to receive(:identifier_str).and_return(doi)
      allow(resource).to receive(:identifier_value).and_return(doi_value)

      @delivery_method = ActionMailer::Base.delivery_method
      ActionMailer::Base.delivery_method = :test

      stash_engine_path = Gem::Specification.find_by_name('stash_engine').gem_dir
      # ActionView::ViewPaths.append_view_path("#{stash_engine_path}/app/views/stash_engine/user_mailer")
      ActionMailer::Base._view_paths.push("#{stash_engine_path}/app/views")

      @sender_address = APP_CONFIG['feedback_email_from']
      @feedback_address = APP_CONFIG['feedback_email_to']

      allow_any_instance_of(ActionView::Helpers::UrlHelper)
        .to receive(:url_for)
        .with(kind_of(String)) do |_, plain_url|
        plain_url
      end
      allow_any_instance_of(ActionView::Helpers::UrlHelper)
        .to receive(:url_for)
        .with(kind_of(Hash)) do |_, url_params|
        "http://#{url_params[:host]}:#{url_params[:port]}/#{url_params[:controller]}"
      end
    end

    after(:each) do
      ActionMailer::Base.deliveries.clear
      ActionMailer::Base.delivery_method = @delivery_method
    end

    describe '#create_succeeded' do
      it 'sends a success email' do
        UserMailer.create_succeeded(resource, title, request_host, request_port).deliver_now
        deliveries = ActionMailer::Base.deliveries
        expect(deliveries.size).to eq(1)
        delivery = deliveries[0]

        expected_headers = {
          'Return-Path' => sender_address,
          'From' => "Dash Notifications <#{sender_address}>",
          'To' => user.email,
          'Subject' => "Dataset submitted: #{title}"
        }

        headers = delivery.header.fields.map { |field| [field.name, field.value] }.to_h
        expected_headers.each do |k, v|
          expect(headers[k]).to eq(v)
        end

        expect(delivery.body.to_s).to include("<a href=\"https://doi.org/#{doi_value}\">#{doi}</a>")
      end
    end

    describe '#create_failed' do
      it 'sends a failure email' do
        error = ArgumentError.new
        UserMailer.create_failed(resource, title, request_host, request_port, error).deliver_now
        deliveries = ActionMailer::Base.deliveries
        expect(deliveries.size).to eq(1)
        delivery = deliveries[0]

        expected_headers = {
          'Return-Path' => sender_address,
          'From' => "Dash Notifications <#{sender_address}>",
          'To' => user.email,
          'Subject' => "Dataset submission failure: #{title}"
        }

        headers = delivery.header.fields.map { |field| [field.name, field.value] }.to_h
        expected_headers.each do |k, v|
          expect(headers[k]).to eq(v)
        end

        expect(delivery.body.to_s).to include("<a href=\"https://doi.org/#{doi_value}\">#{doi}</a>")
      end
    end

    describe '#update_succeeded' do
      it 'sends a success email' do
        UserMailer.update_succeeded(resource, title, request_host, request_port).deliver_now
        deliveries = ActionMailer::Base.deliveries
        expect(deliveries.size).to eq(1)
        delivery = deliveries[0]

        expected_headers = {
          'Return-Path' => sender_address,
          'From' => "Dash Notifications <#{sender_address}>",
          'To' => user.email,
          'Subject' => "Dataset \"#{title}\" (#{doi}) updated"
        }

        headers = delivery.header.fields.map { |field| [field.name, field.value] }.to_h
        expected_headers.each do |k, v|
          expect(headers[k]).to eq(v)
        end

        expect(delivery.body.to_s).to include("<a href=\"https://doi.org/#{doi_value}\">#{doi}</a>")
      end
    end

    describe '#update_failed' do
      it 'sends a failure email' do
        error = ArgumentError.new
        UserMailer.update_failed(resource, title, request_host, request_port, error).deliver_now
        deliveries = ActionMailer::Base.deliveries
        expect(deliveries.size).to eq(1)
        delivery = deliveries[0]

        expected_headers = {
          'Return-Path' => sender_address,
          'From' => "Dash Notifications <#{sender_address}>",
          'To' => user.email,
          'Subject' => "Updating dataset \"#{title}\" (#{doi}) failed"
        }

        headers = delivery.header.fields.map { |field| [field.name, field.value] }.to_h
        expected_headers.each do |k, v|
          expect(headers[k]).to eq(v)
        end

        expect(delivery.body.to_s).to include("<a href=\"https://doi.org/#{doi_value}\">#{doi}</a>")
      end
    end

    describe '#error_report' do
      it 'sends an error report email' do
        error = ArgumentError.new
        UserMailer.error_report(resource, title, error).deliver_now
        deliveries = ActionMailer::Base.deliveries
        expect(deliveries.size).to eq(1)
        delivery = deliveries[0]

        expected_headers = {
          'Return-Path' => sender_address,
          'From' => "Dash Notifications <#{sender_address}>",
          'To' => feedback_address.join(','),
          'Subject' => "Submitting dataset \"#{title}\" (#{doi}) failed"
        }

        headers = delivery.header.fields.map { |field| [field.name, field.value] }.to_h
        expected_headers.each do |k, v|
          expect(headers[k]).to eq(v)
        end

        body = delivery.body.to_s
        expect(body).to include("<a href=\"https://doi.org/#{doi_value}\">#{doi}</a>")
        expect(body).to include("<a href=\"mailto:#{user.email}\">#{user.first_name} #{user.last_name}</a>")
      end
    end
  end
end
