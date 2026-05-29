# frozen_string_literal: true

require_relative 'api_client'

module TickIt
  class DeleteEvent < ApiClient
    class Forbidden < StandardError; end
    class NotFound < StandardError; end

    def call(id:)
      response = http_client.delete("#{api_url}/events/#{id}")

      case response.status
      when 200 then true
      when 403 then raise Forbidden, error_message(response.body, 'Insufficient permissions')
      when 404 then raise NotFound, 'Event not found'
      else raise Error.new(error_message(response.body, "API error (status: #{response.status})"),
                           status: response.status)
      end
    rescue HTTP::Error => e
      raise Error.new("Could not reach API: #{e.message}")
    end
  end
end
