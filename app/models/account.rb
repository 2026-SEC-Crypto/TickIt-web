# frozen_string_literal: true

module TickIt
  # Represents a logged-in account, including the auth token issued by the API.
  class Account
    attr_reader :id, :username, :email, :role, :auth_token

    def initialize(id:, email:, role:, auth_token: nil, username: nil)
      @id = id
      @username = username
      @email = email
      @role = role
      @auth_token = auth_token
    end

    def admin?
      role == 'admin'
    end

    def organizer?
      role == 'organizer'
    end

    def self.from_api_hash(hash)
      data = hash.transform_keys(&:to_sym)
      new(
        id: data[:id],
        username: data[:username],
        email: data[:email],
        role: data[:role] || 'member',
        auth_token: data[:auth_token]
      )
    end

    def self.from_api_hash_with_token(hash, token:)
      data = hash.transform_keys(&:to_sym)
      new(
        id: data[:id],
        username: data[:username],
        email: data[:email],
        role: data[:role] || 'member',
        auth_token: token
      )
    end
  end
end
