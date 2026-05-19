# frozen_string_literal: true

module TickIt
  class Api < Roda
    route('accounts') do |r|
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
        require_authorization!('create_account', 'Account')

        account_data = JSON.parse(r.body.read)

        account = TickIt::AccountService.create_account(
          email: account_data['email'],
          password: account_data['password'],
          role: account_data['role'] || 'member'
        )

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
