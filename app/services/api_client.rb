# frozen_string_literal: true

require 'http'
require 'json'

module TickIt
  class ApiClient
    class Error < StandardError
      attr_reader :status, :body

      def initialize(message, status: nil, body: nil)
        super(message)
        @status = status
        @body = body
      end
    end

    def initialize(token: nil)
      @token = token
    end

    def self.api_url
      ENV.fetch('API_URL', 'http://localhost:9292/api/v1')
    end

    def api_url
      self.class.api_url
    end

    def http_client
      return HTTP.auth("Bearer #{@token}") if @token

      HTTP
    end

    def parse_json(body)
      JSON.parse(body.to_s)
    rescue JSON::ParserError
      {}
    end

    def error_message(body, fallback)
      parsed = body.is_a?(Hash) ? body : parse_json(body)
      parsed['error'] || parsed['message'] || fallback
    end
  end
end
