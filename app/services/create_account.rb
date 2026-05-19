# frozen_string_literal: true

require_relative 'api_client'

module TickIt
  class CreateAccount < ApiClient
    class InvalidAccount < StandardError; end

    def call(email:, password:, role: 'member')
      response = HTTP.post(
        "#{api_url}/auth/register",
        json: { email: email, password: password, role: role }
      )

      case response.status
      when 201
        body = parse_json(response.body)
        SessionUser.from_api_hash(body.fetch('account'))
      when 400, 409
        raise InvalidAccount, error_message(response.body, 'Registration failed')
      else
        raise InvalidAccount,
              error_message(response.body, "API rejected the request (status: #{response.status})")
      end
    rescue HTTP::Error => e
      raise InvalidAccount, "Could not reach API: #{e.message}"
    end
  end
end
