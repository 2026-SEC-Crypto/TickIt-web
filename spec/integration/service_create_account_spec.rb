# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Create Account Service' do
  before do
    @account_data = { email: 'test@example.com', username: 'testuser', password: 'password123' }

    @api_response = { message: 'Account created', data: { id: 1, username: 'testuser', email: 'test@example.com' } }

    ENV['API_URL'] = 'http://api.fake.com/api/v1'
    @api_url = ENV.fetch('API_URL', nil)
  end

  after do
    WebMock.reset!
    ENV.delete('API_URL')
  end

  it 'HAPPY: should send post request to API and return success without hitting real API' do
    stub_request(:post, "#{@api_url}/accounts")
      .with(
        body: @account_data.to_json,
        headers: { 'Content-Type' => 'application/json; charset=utf-8' }
      )
      .to_return(
        status: 201,
        body: @api_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = TickIt::CreateAccount.new.call(**@account_data)

    expect(result['message']).to eq('Account created')
    expect(result['data']['username']).to eq('testuser')
  end
end
