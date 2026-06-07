# frozen_string_literal: true

require_relative 'api_client'

module TickIt
  class CreateEvent < ApiClient
    class InvalidEvent < StandardError; end
    class Forbidden < StandardError; end

    def call(name:, location:, start_time:, end_time:,
             attendance_start_time: nil, attendance_end_time: nil,
             description: nil, repeat_weeks: nil)
      payload = {
        name: name,
        location: location,
        start_time: start_time,
        end_time: end_time,
        attendance_start_time: attendance_start_time,
        attendance_end_time: attendance_end_time,
        description: description,
        repeat_weeks: repeat_weeks
      }.compact

      response = http_client.post("#{api_url}/events", json: TickIt::SignedMessage.sign(payload))

      case response.status
      when 201
        body = parse_json(response.body)
        # Returns single event or first of a series
        event_data = body['event'] || body.fetch('events', []).first
        Event.from_api_hash(event_data)
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
