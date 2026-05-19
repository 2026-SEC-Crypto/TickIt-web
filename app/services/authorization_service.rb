# frozen_string_literal: true

require_relative '../../lib/security_log'

module TickIt
  # Authorization service for managing role-based access control
  # Provides methods to check user permissions and guard unauthorized behaviors
  class AuthorizationService
    # Define permission levels for different actions
    PERMISSIONS = {
      # User account actions
      view_own_account: %w[member admin organizer],
      update_own_account: %w[member admin organizer],
      delete_own_account: %w[member admin organizer],
      view_all_accounts: ['admin'],
      update_any_account: ['admin'],
      delete_any_account: ['admin'],

      # Event actions
      view_events: %w[member admin organizer],
      create_event: %w[admin organizer],
      update_own_event: %w[admin organizer],
      update_any_event: ['admin'],
      delete_own_event: %w[admin organizer],
      delete_any_event: ['admin'],

      # Attendance actions
      view_own_attendance: %w[member admin organizer],
      view_all_attendance: %w[admin organizer],
      record_attendance: %w[admin organizer],
      edit_attendance: %w[admin organizer],
      delete_attendance: ['admin']
    }.freeze

    # Check if an account has permission for an action
    # @param account [Account] The account to check permissions for
    # @param action [Symbol] The action to check (e.g., :create_event)
    # @return [Boolean] True if account is authorized, false otherwise
    def self.authorized?(account, action)
      return false if account.nil?

      allowed_roles = PERMISSIONS[action]
      return false unless allowed_roles

      allowed_roles.include?(account.role)
    end

    # Check if one account can act on another account's data
    # Used for ensuring users can only modify their own data (unless admin)
    # @param acting_account [Account] The account performing the action
    # @param target_account [Account] The account being acted upon
    # @param action [Symbol] The action being performed
    # @return [Boolean] True if acting_account can act on target_account
    def self.can_act_on_account?(acting_account, target_account, action)
      return false if acting_account.nil? || target_account.nil?

      # Admins can act on any account
      return true if acting_account.admin?

      # Non-admins can only act on their own account
      acting_account.id == target_account.id
    end

    # Check if user can view/manage a specific event
    # @param account [Account] The account checking permission
    # @param event [Event] The event being accessed
    # @param action [Symbol] The action being performed
    # @return [Boolean] True if authorized
    def self.can_act_on_event?(account, event, action)
      return false if account.nil? || event.nil?

      case action
      when :view
        # Anyone can view events
        authorized?(account, :view_events)
      when :edit, :update
        # Only admin or event organizer can edit
        return true if account.admin?

        # Check if account is the creator/organizer
        event.account_id == account.id
      when :delete
        # Only admin or event organizer can delete
        return true if account.admin?

        # Check if account is the creator/organizer
        event.account_id == account.id
      else
        false
      end
    end

    # Log unauthorized access attempts
    # @param account [Account] The account that attempted unauthorized action
    # @param action [Symbol] The unauthorized action
    # @param resource [String] Description of the resource being accessed
    def self.log_unauthorized_attempt(account, action, resource)
      SecurityLog.log_security_event(
        "unauthorized_#{action}",
        "User #{account&.id || 'Unknown'} attempted unauthorized action on #{resource}",
        :warn
      )
    end

    # Get role display name for UI
    # @param role [String] The role string
    # @return [String] Human-readable role name
    def self.role_display(role)
      case role
      when 'admin'
        'Administrator'
      when 'organizer'
        'Event Organizer'
      when 'member'
        'Member'
      else
        role.capitalize
      end
    end

    # Get all available roles
    # @return [Array<String>] List of available roles
    def self.available_roles
      %w[member organizer admin]
    end
  end
end
