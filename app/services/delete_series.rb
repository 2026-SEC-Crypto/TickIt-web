# frozen_string_literal: true

require_relative 'api_client'

module TickIt
  class DeleteSeries < ApiClient
    class Forbidden < StandardError; end
    class NotFound < StandardError; end

    def call(series_id:)
      response = http_client.delete("#{api_url}/events/series/#{series_id}")

      case response.status
      when 200 then parse_json(response.body)
      when 403 then raise Forbidden, error_message(response.body, 'Insufficient permissions')
      when 404 then raise NotFound, 'Series not found'
      else raise Error.new(error_message(response.body, "API error (status: #{response.status})"),
                           status: response.status)
      end
    rescue HTTP::Error => e
      raise Error.new("Could not reach API: #{e.message}")
    end
  end
end
