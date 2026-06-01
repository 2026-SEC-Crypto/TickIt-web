# frozen_string_literal: true

require_relative 'api_client'

module TickIt
  class FetchApiKey < ApiClient
    def call
      response = http_client.post("#{api_url}/auth/api_key")

      case response.status
      when 200
        body = parse_json(response.body)
        body['api_key']
      when 401
        raise Error.new('Unauthorized', status: 401)
      else
        raise Error.new(error_message(response.body, "Failed to generate API key (status: #{response.status})"),
                        status: response.status)
      end
    rescue HTTP::Error => e
      raise Error.new("Could not reach API: #{e.message}")
    end
  end
end
