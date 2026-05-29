# frozen_string_literal: true

require_relative 'api_client'

module TickIt
  class FetchEvents < ApiClient
    def call(mine: false)
      url = mine ? "#{api_url}/events?mine=true" : "#{api_url}/events"
      response = http_client.get(url)

      case response.status
      when 200
        body = parse_json(response.body)
        body.fetch('events', []).map { |e| Event.from_api_hash(e) }
      else
        raise Error.new(
          error_message(response.body, "Failed to load events (status: #{response.status})"),
          status: response.status, body: response.body.to_s
        )
      end
    rescue HTTP::Error => e
      raise Error.new("Could not reach API: #{e.message}")
    end
  end
end
