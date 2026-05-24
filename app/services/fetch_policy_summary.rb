# frozen_string_literal: true

require_relative 'api_client'

module TickIt
  class FetchPolicySummary
    class Error < StandardError; end

    def initialize(token: nil)
      @token = token
    end

    def call
      client = ApiClient.new(token: @token)
      url = client.api_url.sub(%r{/v1$}, '') + '/v1/policies/summary'
      response = client.http_client.get(url)
      raise Error, "API error: #{response.status}" unless response.status.success?
      client.parse_json(response.body)
    rescue StandardError => e
      raise Error, e.message
    end
  end
end
