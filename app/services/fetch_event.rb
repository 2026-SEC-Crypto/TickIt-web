# frozen_string_literal: true

require_relative 'api_client'

module TickIt
  class FetchEvent < ApiClient
    class NotFound < StandardError; end

    def call(id:)
      response = http_client.get("#{api_url}/events/#{id}")

      case response.status
      when 200
        body = parse_json(response.body)
        event     = Event.from_api_hash(body.fetch('event'))
        attendees = body.fetch('attendees', [])
        policy    = body.fetch('policy', {})
        { event: event, attendees: attendees, policy: policy }
      when 404
        raise NotFound, 'Event not found'
      else
        raise Error.new(error_message(response.body, "Failed to load event (status: #{response.status})"),
                        status: response.status)
      end
    rescue HTTP::Error => e
      raise Error.new("Could not reach API: #{e.message}")
    end
  end
end
