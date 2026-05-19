# frozen_string_literal: true

require 'digest'
require_relative '../models/account'
require_relative '../models/event'
require_relative '../../lib/security_log'

module TickIt
  # Service object for managing Account resources
  class AccountService
    # Retrieve all accounts (only public information)
    def self.all_accounts
      Account.map { |acc| account_to_api_hash(acc) }
    end

    # Retrieve a single account by ID
    def self.find_account(id)
      Account.first(id: id.to_s)
    end

    # Create a new account with validation
    def self.create_account(email:, password:, role: 'member')
      validate_account_params(email:, password:)

      Account.create(
        email:,
        password:,
        role:
      )
    rescue Sequel::UniqueConstraintViolation, SQLite3::ConstraintException
      raise "Account with email '#{email}' already exists"
    end

    # Authenticate account with password
    def self.authenticate(email:, password:)
      # Find account by email hash for security
      account = find_by_email(email)
      return nil unless account
      return nil unless account.password?(password)

      account
    end

    # Find account by email
    def self.find_by_email(email)
      email_hash = Digest::SHA256.hexdigest(email)
      Account.first(email_hash:)
    end

    # Update account (limited fields to prevent mass assignment)
    def self.update_account(account_id, **updates)
      account = find_account(account_id)
      raise "Account not found with id: #{account_id}" unless account

      # Only allow safe updates
      safe_updates = {}
      safe_updates[:role] = updates[:role] if updates.key?(:role) && valid_role?(updates[:role])
      safe_updates[:password] = updates[:password] if updates.key?(:password)

      account.update(safe_updates) if safe_updates.any?
      account
    end

    # Delete an account
    def self.delete_account(account_id)
      account = find_account(account_id)
      raise "Account not found with id: #{account_id}" unless account

      account.delete
    end

    # Add account as collaborator to an event
    def self.add_collaborator(account_id, event_id)
      account = find_account(account_id)
      raise "Account not found with id: #{account_id}" unless account

      event = Event.with_pk(event_id.to_s)
      raise "Event not found with id: #{event_id}" unless event

      account.add_collaborated_event(event) unless account.collaborated_events.include?(event)
      account
    end

    # Remove account as collaborator from an event
    def self.remove_collaborator(account_id, event_id)
      account = find_account(account_id)
      raise "Account not found with id: #{account_id}" unless account

      event = Event.with_pk(event_id.to_s)
      raise "Event not found with id: #{event_id}" unless event

      account.remove_collaborated_event(event)
      account
    end

    private

    def self.validate_account_params(email:, password:)
      raise ArgumentError, 'Email cannot be empty' if email.nil? || (email.is_a?(String) && email.strip.empty?)
      if password.nil? || (password.is_a?(String) && password.strip.empty?)
        raise ArgumentError,
              'Password cannot be empty'
      end
      raise 'Invalid email format' unless valid_email?(email)
    end

    def self.valid_email?(email)
      email.is_a?(String) && email.include?('@')
    end

    def self.valid_role?(role)
      %w[member admin organizer].include?(role)
    end

    def self.account_to_api_hash(account)
      {
        id: account.id,
        email: account.email,
        role: account.role
      }
    end
  end
end
