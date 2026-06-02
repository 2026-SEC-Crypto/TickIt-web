# frozen_string_literal: true

require_relative 'api_client'

module TickIt
  class SubmitTeacherApplication < ApiClient
    class AlreadyApplied < StandardError; end
    class Forbidden < StandardError; end
    class InvalidData < StandardError; end

    def call(real_name:, organization:, school_email:, notes: nil)
      body = { real_name: real_name, organization: organization, school_email: school_email, notes: notes }
      response = http_client.post("#{api_url}/applications",
                                  json: body)

      case response.status
      when 201
        parse_json(response.body)
      when 409
        raise AlreadyApplied, error_message(response.body, 'You already have a pending application')
      when 422
        raise InvalidData, error_message(response.body, 'Invalid application data')
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
