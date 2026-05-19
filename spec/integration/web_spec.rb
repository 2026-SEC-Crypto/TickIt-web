# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../app/controllers/app'

RSpec.describe 'TickIt Web' do
  include Rack::Test::Methods

  def app
    TickIt::Web.freeze.app
  end

  let(:api_url) { ENV.fetch('API_URL') }

  after { WebMock.reset! }

  describe 'GET /home' do
    it 'renders the home page' do
      get '/home'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('TickIt')
    end
  end

  describe 'GET /' do
    it 'redirects to home' do
      get '/'
      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to eq('/home')
    end
  end

  describe 'POST /login' do
    it 'logs in via API and shows account page' do
      stub_request(:post, "#{api_url}/auth/authenticate")
        .to_return(
          status: 200,
          body: {
            account: { id: 'u1', email: 'user@example.com', role: 'member' }
          }.to_json
        )
      stub_request(:get, "#{api_url}/accounts/u1")
        .to_return(
          status: 200,
          body: {
            account: { id: 'u1', email: 'user@example.com', role: 'member' }
          }.to_json
        )

      post '/login', email: 'user@example.com', password: 'secret'

      expect(last_response.status).to eq(302)
      follow_redirect!
      expect(last_response.body).to include('user@example.com')

      get '/home'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('You are logged in')
      expect(last_response.body).to include('user@example.com')
    end

    it 'shows error on invalid credentials' do
      stub_request(:post, "#{api_url}/auth/authenticate")
        .to_return(status: 403, body: { error: 'Invalid credentials' }.to_json)

      post '/login', email: 'user@example.com', password: 'wrong'

      expect(last_response.status).to eq(401)
      expect(last_response.body).to include('Invalid email or password')
    end
  end

  describe 'POST /register' do
    it 'registers via API and shows account page' do
      stub_request(:post, "#{api_url}/auth/register")
        .to_return(
          status: 201,
          body: {
            message: 'Account created successfully',
            account: { id: 'u2', email: 'new@example.com', role: 'member' }
          }.to_json
        )
      stub_request(:get, "#{api_url}/accounts/u2")
        .to_return(
          status: 200,
          body: {
            account: { id: 'u2', email: 'new@example.com', role: 'member' }
          }.to_json
        )

      post '/register',
           email: 'new@example.com',
           password: 'password123',
           password_confirm: 'password123'

      expect(last_response.status).to eq(302)
      follow_redirect!

      get '/home'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('You are logged in')
      expect(last_response.body).to include('new@example.com')
    end
  end

  describe 'GET /account' do
    it 'redirects to login when not authenticated' do
      get '/account'
      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to eq('/login')
    end
  end
end
