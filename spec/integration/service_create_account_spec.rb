# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../app/lib/bootstrap'
require 'registration_token'
require 'webmock/rspec'

RSpec.describe EmailService do
  before do
    stub_request(:post, /api.mailgun.net/).to_return(status: 200, body: '', headers: {})
  end

  it 'sends a verification email' do
    email = 'test@example.com'
    verification_url = 'http://example.com/verify_registration?token=abc123'

    service = EmailService.new
    response = service.send_verification_email(email, verification_url)

    expect(response.code).to eq(200)
    expect(WebMock).to have_requested(:post, /api.mailgun.net/).once
  end
end

RSpec.describe RegistrationToken do
  let(:username) { 'testuser' }
  let(:email) { 'test@example.com' }
  let(:token) { RegistrationToken.generate(username, email) }

  before do
    allow(SecureMessage).to receive(:encrypt).and_call_original
    allow(SecureMessage).to receive(:decrypt).and_call_original
  end

  it 'generates a valid token' do
    expect(token).not_to be_nil
    expect(SecureMessage).to have_received(:encrypt).once
  end

  it 'decodes a valid token' do
    decoded = RegistrationToken.decode(token)
    expect(decoded[:username]).to eq(username)
    expect(decoded[:email]).to eq(email)
  end

  it 'returns nil for an expired token' do
    allow(Time).to receive(:now).and_return(Time.now + 7200) # Simulate 2 hours later
    expect(RegistrationToken.decode(token)).to be_nil
  end

  it 'returns nil for an invalid token' do
    expect(RegistrationToken.decode('invalid.token')).to be_nil
  end
end

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
