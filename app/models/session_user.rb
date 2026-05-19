# frozen_string_literal: true

module TickIt
  # Lightweight user object built from API responses or encrypted session data.
  class SessionUser
    attr_reader :id, :email, :role

    def initialize(id:, email:, role:)
      @id = id
      @email = email
      @role = role
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
        email: data[:email],
        role: data[:role] || 'member'
      )
    end
  end
end
