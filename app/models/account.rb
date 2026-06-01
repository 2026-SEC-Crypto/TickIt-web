# frozen_string_literal: true

module TickIt
  # Represents a logged-in account, including the auth token issued by the API.
  class Account
    attr_reader :id, :username, :email, :role, :auth_token, :avatar_url

    def initialize(id:, email:, role:, auth_token: nil, username: nil, avatar_url: nil)
      @id = id
      @username = username
      @email = email
      @role = role
      @auth_token = auth_token
      @avatar_url = avatar_url
    end

    def admin?
      role == 'admin'
    end

    def teacher?
      role == 'teacher'
    end

    def self.from_api_hash(hash, fallback: {})
      data = fallback.transform_keys(&:to_sym).merge(hash.transform_keys(&:to_sym))
      new(
        id: data[:id],
        username: data[:username] || data[:name],
        email: data[:email],
        role: data[:role] || 'regular',
        auth_token: data[:auth_token],
        avatar_url: data[:avatar_url] || data[:picture]
      )
    end

    def self.from_api_hash_with_token(hash, token:, fallback: {})
      data = fallback.transform_keys(&:to_sym).merge(hash.transform_keys(&:to_sym))
      new(
        id: data[:id],
        username: data[:username] || data[:name],
        email: data[:email],
        role: data[:role] || 'regular',
        auth_token: token,
        avatar_url: data[:avatar_url] || data[:picture]
      )
    end
  end
end
