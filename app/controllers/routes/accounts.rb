# frozen_string_literal: true

module TickIt
  class Api < Roda
    route('accounts') do |r|
      puts '--- API DEBUG: accounts.rb ---'
      r.get String do |account_id|
        account = TickIt::AccountService.find_account(account_id)

        if account.nil?
          response.status = 404
          next({ error: 'Account not found' }.to_json)
        end

        response.status = 200
        {
          account: {
            id: account.id,
            email: account.email,
            role: account.role
          }
        }.to_json
      end

      r.post do
        # Only admins can create accounts (403 if unauthorized)
        # require_authorization!('create_account', 'Account')
        raw_body = r.body.read
        puts "--- API DEBUG:  #{raw_body.inspect} ---"

        begin
          puts '--- API start---'
          account_data = JSON.parse(raw_body)
        rescue JSON::ParserError
          puts '--- API ERROR: JSON failed---'
          r.halt 400, { error: 'Invalid JSON' }.to_json
        end

        puts '--- API start2---'
        begin
          # 這裡是你的嫌疑犯行
          account = TickIt::AccountService.create_account(
            email: account_data['email'],
            password: account_data['password']
          )

          response.status = 201
          { message: 'Created', account: account }.to_json
        rescue StandardError => e
          # 🌟 這兩行會告訴你真相

          response.status = 400
          { error: e.message }.to_json
        end
        response.status = 201
        {
          message: 'Account created successfully',
          account: { id: account.id, email: account.email, role: account.role }
        }.to_json
      rescue JSON::ParserError
        response.status = 400
        { error: 'Invalid JSON format' }.to_json
      rescue ArgumentError => e
        response.status = 400
        { error: e.message }.to_json
      rescue StandardError => e
        response.status = 400
        { error: e.message }.to_json
      end
    end
  end
end
