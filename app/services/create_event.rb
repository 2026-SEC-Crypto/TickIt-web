# frozen_string_literal: true

require_relative 'api_client'

module TickIt
  class CreateEvent < ApiClient
    class InvalidEvent < StandardError; end
    class Forbidden < StandardError; end

    def call(name:, location:, start_time:, end_time:,
             attendance_start_time: nil, attendance_end_time: nil, description: nil)
      payload = {
        name: name,
        location: location,
        start_time: start_time,
        end_time: end_time,
        attendance_start_time: attendance_start_time,
        attendance_end_time: attendance_end_time,
        description: description
      }.compact

      response = http_client.post("#{api_url}/events", json: payload)

      case response.status
      when 201
        body = parse_json(response.body)
        Event.from_api_hash(body.fetch('event'))
      when 400
        raise InvalidEvent, error_message(response.body, 'Invalid event data')
      when 401
        raise Error.new('Unauthorized', status: 401)
      when 403
        raise Forbidden, error_message(response.body, 'Insufficient permissions')
      else
        raise InvalidEvent, error_message(response.body, "API error (status: #{response.status})")
      end
    rescue HTTP::Error => e
      raise InvalidEvent, "Could not reach API: #{e.message}"
    end
  end
end
