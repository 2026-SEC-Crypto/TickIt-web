# frozen_string_literal: true

require_relative 'api_client'

module TickIt
  class FetchAccount < ApiClient
    class NotFound < StandardError; end

    def call(id:)
      response = HTTP.get("#{api_url}/accounts/#{id}")

      case response.status
      when 200
        body = parse_json(response.body)
        SessionUser.from_api_hash(body.fetch('account'))
      when 404
        raise NotFound, 'Account not found'
      else
        raise Error, error_message(response.body, "Failed to load account (status: #{response.status})"),
              status: response.status, body: response.body.to_s
      end
    rescue HTTP::Error => e
      raise Error, "Could not reach API: #{e.message}"
    end
  end
end
