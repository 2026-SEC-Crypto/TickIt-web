# frozen_string_literal: true

require 'uri'
require_relative '../spec_helper'
require_relative '../../app/controllers/app'

RSpec.describe 'Google SSO' do
  include Rack::Test::Methods

  def app
    TickIt::Web.freeze.app
  end

  let(:api_url) { ENV.fetch('API_URL') }

  after { WebMock.reset! }

  describe 'GET /login/google' do
    it 'redirects to the Google authorization endpoint' do
      stub_request(:get, 'https://accounts.google.com/.well-known/openid-configuration')
        .to_return(
          status: 200,
          body: {
            authorization_endpoint: 'https://accounts.google.com/o/oauth2/v2/auth'
          }.to_json
        )

      get '/login/google'

      expect(last_response.status).to eq(302)

      location = URI.parse(last_response.headers['Location'])
      params = Rack::Utils.parse_query(location.query)

      expect(location.to_s).to start_with('https://accounts.google.com/o/oauth2/v2/auth')
      expect(params['client_id']).to eq('test-google-client-id')
      expect(params['redirect_uri']).to eq(ENV.fetch('GOOGLE_REDIRECT_URI'))
      expect(params['scope']).to eq('openid email profile')
    end
  end

  describe 'GET /auth/google/callback' do
    it 'creates a session after Google authentication' do
      stub_request(:get, 'https://accounts.google.com/.well-known/openid-configuration')
        .to_return(
          status: 200,
          body: {
            authorization_endpoint: 'https://accounts.google.com/o/oauth2/v2/auth'
          }.to_json
        )

      get '/login/google'
      params = Rack::Utils.parse_query(URI.parse(last_response.headers['Location']).query)

      account = TickIt::Account.new(
        id: 'google-1',
        username: 'Google User',
        email: 'google-user@example.com',
        role: 'member',
        avatar_url: 'https://example.test/avatar.png'
      )

      allow_any_instance_of(TickIt::GoogleSsoService).to receive(:authenticate).and_return(account)

      stub_request(:get, "#{api_url}/policies/summary")
        .to_return(status: 200, body: { policies: {} }.to_json)

      get '/auth/google/callback', code: 'auth-code-1', state: params['state']

      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to eq('/account')
    end
  end
end