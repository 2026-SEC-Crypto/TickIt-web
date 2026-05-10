# frozen_string_literal: true

require 'http'
require 'json'

module TickIt
  class CreateAccount
    class InvalidAccount < StandardError; end

    def call(email:, username:, password:)
      api_url = ENV.fetch('API_URL', 'http://localhost:9292/api/v1')

      response = HTTP.post(
        "#{api_url}/accounts",
        json: { email: email, username: username, password: password }
      )

      raise InvalidAccount, "API rejected the request (status: #{response.status})" unless response.status == 201

      JSON.parse(response.body.to_s)
    end
  end
end
