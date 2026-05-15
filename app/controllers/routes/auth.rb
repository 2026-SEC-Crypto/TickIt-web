# frozen_string_literal: true

module TickIt
  class Api < Roda
    route('auth') do |r|
      # POST /api/v1/auth/authenticate
      r.on 'authenticate' do
        r.post do
          credentials = JSON.parse(r.body.read, symbolize_names: true)
          puts "--- API AUTH DEBUG: Received Email: #{credentials[:email]} ---"
          account = TickIt::AccountService.authenticate(
            email: credentials[:email],
            password: credentials[:password]
          )

          if account
            response.status = 200
            {
              account: {
                id: account.id,
                email: account.email,
                role: account.role
              }
            }.to_json
          else
            response.status = 403
            { error: 'Invalid credentials' }.to_json
          end
        rescue JSON::ParserError
          response.status = 400
          { error: 'Invalid JSON format' }.to_json
        end
      end
    end
  end
end
