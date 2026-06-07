# frozen_string_literal: true

require_relative 'api_client'

module TickIt
  class AuthenticateAccount < ApiClient
    class AuthenticationFailed < StandardError; end

    def call(email:, password:)
      signed = TickIt::SignedMessage.sign({ email: email, password: password })
      response = http_client.post(
        "#{api_url}/auth/authenticate",
        json: signed
      )

      case response.status
      when 200
        body = parse_json(response.body)
        Account.from_api_hash(body.fetch('account'))
      when 401
        nil
      when 400
        raise AuthenticationFailed, error_message(response.body, 'Invalid request')
      else
        raise Error.new(
          error_message(response.body, "Authentication failed (status: #{response.status})"),
          status: response.status, body: response.body.to_s
        )
      end
    rescue HTTP::Error => e
      raise Error.new("Could not reach API: #{e.message}")
    end
  end
end
