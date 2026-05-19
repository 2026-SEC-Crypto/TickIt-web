# frozen_string_literal: true

module TickIt
  class Api < Roda
    route('auth') do |r|
      # 處理 POST /api/v1/auth/authenticate
      r.on 'authenticate' do
        r.post do
          credentials = JSON.parse(r.body.read, symbolize_names: true)

          # 這裡需要確保你的 AccountService 裡有 authenticate 方法
          account = TickIt::AccountService.authenticate(credentials)

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
