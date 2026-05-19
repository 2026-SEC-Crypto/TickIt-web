# frozen_string_literal: true

require_relative '../../lib/security_log'

module TickIt
  # Session helpers for the web tier (cookie session only; no database).
  class SessionService
    def self.log_user_action(account_id, action)
      SecurityLog.log(
        user_id: account_id,
        action: action,
        timestamp: Time.now
      )
    end
  end
end
