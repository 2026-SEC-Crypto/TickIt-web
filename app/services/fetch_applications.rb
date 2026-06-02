# frozen_string_literal: true

require_relative 'api_client'

module TickIt
  class FetchApplications < ApiClient
    def call
      response = http_client.get("#{api_url}/applications")

      case response.status
      when 200
        parse_json(response.body).fetch('applications', [])
      when 403
        raise Error.new('Forbidden: admin only', status: 403)
      else
        raise Error.new(
          error_message(response.body, "Failed to load applications (status: #{response.status})"),
          status: response.status, body: response.body.to_s
        )
      end
    rescue HTTP::Error => e
      raise Error.new("Could not reach API: #{e.message}")
    end
  end
end
