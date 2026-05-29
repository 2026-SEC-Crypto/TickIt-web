# frozen_string_literal: true

require_relative 'api_client'

module TickIt
  class UpdateEvent < ApiClient
    class InvalidEvent < StandardError; end
    class Forbidden < StandardError; end

    def call(id:, **fields)
      response = http_client.patch("#{api_url}/events/#{id}", json: fields.compact)

      case response.status
      when 200
        body = parse_json(response.body)
        Event.from_api_hash(body.fetch('event'))
      when 400
        raise InvalidEvent, error_message(response.body, 'Invalid event data')
      when 403
        raise Forbidden, error_message(response.body, 'Insufficient permissions')
      when 404
        raise InvalidEvent, 'Event not found'
      else
        raise InvalidEvent, error_message(response.body, "API error (status: #{response.status})")
      end
    rescue HTTP::Error => e
      raise InvalidEvent, "Could not reach API: #{e.message}"
    end
  end
end
