# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../app/lib/bootstrap'

describe TickIt::CreateAccount do
  let(:api_url) { ENV.fetch('API_URL') }

  after { WebMock.reset! }

  it 'posts to auth/register and returns a SessionUser' do
    stub_request(:post, "#{api_url}/auth/register")
      .with(body: { email: 'test@example.com', password: 'password123', role: 'member' }.to_json)
      .to_return(
        status: 201,
        body: {
          message: 'Account created successfully',
          account: { id: 'acc-1', email: 'test@example.com', role: 'member' }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    user = described_class.new.call(email: 'test@example.com', password: 'password123')

    expect(user).to be_a(TickIt::SessionUser)
    expect(user.email).to eq('test@example.com')
    expect(user.role).to eq('member')
  end

  it 'raises InvalidAccount when email already exists' do
    stub_request(:post, "#{api_url}/auth/register")
      .to_return(status: 409, body: { error: "Account with email 'test@example.com' already exists" }.to_json)

    expect do
      described_class.new.call(email: 'test@example.com', password: 'password123')
    end.to raise_error(TickIt::CreateAccount::InvalidAccount, /already exists/)
  end
end
