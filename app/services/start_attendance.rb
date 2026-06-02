# frozen_string_literal: true

require_relative 'api_client'

module TickIt
  class StartAttendance < ApiClient
    class Forbidden < StandardError; end
    class OutsideWindow < StandardError; end

    def call(event_id:, lat:, lng:)
      response = http_client.post(
        "#{api_url}/events/#{event_id}/start_attendance",
        json: { lat: lat, lng: lng }
      )

      case response.status
      when 200
        parse_json(response.body)
      when 403
        raise Forbidden, error_message(response.body, 'You do not have permission to start attendance')
      when 422
        raise OutsideWindow, error_message(response.body, 'Cannot start attendance at this time')
      else
        raise Error.new(
          error_message(response.body, "Failed to start attendance (status: #{response.status})"),
          status: response.status, body: response.body.to_s
        )
      end
    rescue HTTP::Error => e
      raise Error.new("Could not reach API: #{e.message}")
    end
  end
end
