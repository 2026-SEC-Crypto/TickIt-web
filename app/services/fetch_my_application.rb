# frozen_string_literal: true

require_relative 'api_client'

module TickIt
  class FetchMyApplication < ApiClient
    def call
      response = http_client.get("#{api_url}/applications/mine")
      return nil unless response.status == 200

      parse_json(response.body)['application']
    rescue StandardError
      nil
    end
  end
end
