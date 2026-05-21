# frozen_string_literal: true

require_relative 'api_client'
require_relative '../lib/registration_token'

module TickIt
  class CreateAccount < ApiClient
    class InvalidAccount < StandardError; end

    def call(email:, password:, role: 'member')
      response = http_client.post(
        "#{api_url}/auth/register",
        json: { email: email, password: password, role: role }
      )

      case response.status
      when 201
        body = parse_json(response.body)
        Account.from_api_hash(body.fetch('account'))
      when 400, 409
        raise InvalidAccount, error_message(response.body, 'Registration failed')
      else
        raise InvalidAccount,
              error_message(response.body, "API rejected the request (status: #{response.status})")
      end
    rescue HTTP::Error => e
      raise InvalidAccount, "Could not reach API: #{e.message}"
    end

    def call_with_validation_flag(username:, email:, password: nil, validated: false)
      response = http_client.post(
        "#{api_url}/auth/register",
        json: { username: username, email: email, password: password, validated: validated }
      )

      case response.status
      when 201
        body = parse_json(response.body)
        Account.from_api_hash(body.fetch('account'))
      when 400, 409
        raise InvalidAccount, error_message(response.body, 'Registration failed')
      else
        raise InvalidAccount,
              error_message(response.body, "API rejected the request (status: #{response.status})")
      end
    rescue HTTP::Error => e
      raise InvalidAccount, "Could not reach API: #{e.message}"
    end

    def check_availability(username:, email:)
      # Removed - API will handle duplicate detection on account creation
      # Always return true to allow registration flow to proceed
      # API will return 409 if email/username already exists
      true
    end

    def generate_verification_url(username:, email:)
      token = RegistrationToken.generate(username, email)
      "#{frontend_url}/verify_registration?token=#{token}"
    end
  end
end
