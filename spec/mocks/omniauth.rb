module Mocks

  module Omniauth

    def mock_shibboleth!(user)
      # Mocks the Omniauth response from Shibboleth
      OmniAuth.config.add_mock(:shibboleth, Mocks::Shibboleth.omniauth_response(user))

      # Stub the call to the Shibboleth Service Provider
      stub_request(:get, %r{Shibboleth\.sso/Login.*})
        .to_return(status: 200, body: '', headers: {})
    end

    def mock_orcid!(user)
      # Mocks the Omniauth response from ORCID
      OmniAuth.config.add_mock(:orcid, Mocks::Orcid.omniauth_response(user))

      # https://api.sandbox.orcid.org/v2.1/5441f05582ea0983f9ad8b683127e6e6/email
      stub_request(:get, %r{api\.sandbox\.orcid\.org/v2\.1/.*/email})
        .with(
          headers: {
            'Accept' => '*/*',
            'Authorization' => /Bearer .*/,
            'Content-Type' => 'application/vnd.orcid+json',
            'Host' => 'api.sandbox.orcid.org'
          }
        ).to_return(status: 200, body: Mocks::Orcid.email_response(user).to_json, headers: {})

      # https://api.sandbox.orcid.org/v2.1/5441f05582ea0983f9ad8b683127e6e6/email
      stub_request(:get, %r{api\.sandbox\.orcid\.org/v2\.1/.*/employments})
        .with(
          headers: {
            'Accept' => '*/*',
            'Authorization' => /Bearer .*/,
            'Content-Type' => 'application/vnd.orcid+json',
            'Host' => 'api.sandbox.orcid.org'
          }
        ).to_return(status: 200, body: Mocks::Orcid.employment_response(user).to_json, headers: {})
    end

  end

end
