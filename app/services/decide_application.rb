# frozen_string_literal: true

require_relative 'api_client'

module TickIt
  class DecideApplication < ApiClient
    class NotFound < StandardError; end

    def call(id:, decision:, reason: nil)
      body = decision == 'reject' && reason.to_s.strip != '' ? { reason: reason } : {}
      response = http_client.patch("#{api_url}/applications/#{id}/#{decision}",
                                   json: body)

      case response.status
      when 200
        parse_json(response.body)
      when 404
        raise NotFound, 'Application not found'
      when 409
        raise Error.new(error_message(response.body, 'Application cannot be updated'), status: 409)
      else
        raise Error.new(
          error_message(response.body, "Failed to update application (status: #{response.status})"),
          status: response.status, body: response.body.to_s
        )
      end
    rescue HTTP::Error => e
      raise Error.new("Could not reach API: #{e.message}")
    end
  end
end
