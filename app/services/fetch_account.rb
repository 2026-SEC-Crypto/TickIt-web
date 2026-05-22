# frozen_string_literal: true

require_relative 'api_client'

module TickIt
  class FetchAccount < ApiClient
    class NotFound < StandardError; end

    def call(id:)
      response = http_client.get("#{api_url}/accounts/#{id}")

      case response.status
      when 200
        body = parse_json(response.body)
        data = body.fetch('account').transform_keys(&:to_sym)
        Account.new(
          id: data[:id],
          email: data[:email],
          role: data[:role] || 'member',
          auth_token: @token
        )
      when 404
        raise NotFound, 'Account not found'
      else
        raise Error.new(
          error_message(response.body, "Failed to load account (status: #{response.status})"),
          status: response.status, body: response.body.to_s
        )
      end
    rescue HTTP::Error => e
      raise Error.new("Could not reach API: #{e.message}")
    end
  end
end
