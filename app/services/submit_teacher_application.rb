# frozen_string_literal: true

require_relative 'api_client'

module TickIt
  class SubmitTeacherApplication < ApiClient
    class AlreadyApplied < StandardError; end
    class Forbidden < StandardError; end

    def call
      response = http_client.post("#{api_url}/applications")

      case response.status
      when 201
        parse_json(response.body)
      when 409
        raise AlreadyApplied, error_message(response.body, 'You already have a pending application')
      when 403
        raise Forbidden, error_message(response.body, 'You are not allowed to apply')
      else
        raise Error.new(
          error_message(response.body, "Failed to submit application (status: #{response.status})"),
          status: response.status, body: response.body.to_s
        )
      end
    rescue HTTP::Error => e
      raise Error.new("Could not reach API: #{e.message}")
    end
  end
end
