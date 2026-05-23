# frozen_string_literal: true

module TickIt
  # Manages storing and loading the current account (including auth token) in the encrypted session.
  class CurrentSession
    def initialize(secure_session)
      @secure_session = secure_session
    end

    def save(account)
      @secure_session.set(:account_id, account.id)
      @secure_session.set(:username, account.username)
      @secure_session.set(:email, account.email)
      @secure_session.set(:role, account.role)
      @secure_session.set(:auth_token, account.auth_token)
    end

    def load
      account_id = @secure_session.get(:account_id)
      return nil unless account_id

      Account.new(
        id: account_id,
        username: @secure_session.get(:username),
        email: @secure_session.get(:email),
        role: @secure_session.get(:role) || 'member',
        auth_token: @secure_session.get(:auth_token)
      )
    end

    def clear!
      @secure_session.delete(:account_id)
      @secure_session.delete(:email)
      @secure_session.delete(:role)
      @secure_session.delete(:auth_token)
    end
  end
end
