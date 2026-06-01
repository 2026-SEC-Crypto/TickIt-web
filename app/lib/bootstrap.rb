# frozen_string_literal: true

require 'dotenv'
Dotenv.load

require_relative 'secure_message'
require_relative 'secure_session'
require_relative 'registration_token'
require_relative '../forms/login_form'
require_relative '../forms/register_form'
require_relative '../forms/set_password_form'
require_relative '../models/account'
require_relative '../models/current_session'
require_relative '../models/event'
require_relative '../services/api_client'
require_relative '../services/authenticate_account'
require_relative '../services/google_sso_service'
require_relative '../services/create_account'
require_relative '../services/email_service'
require_relative '../services/fetch_account'
require_relative '../services/fetch_events'
require_relative '../services/fetch_event'
require_relative '../services/create_event'
require_relative '../services/update_event'
require_relative '../services/delete_event'
require_relative '../services/fetch_api_key'
require_relative '../services/delete_series'
require_relative '../services/update_series'
require_relative '../services/authorization_service'
require_relative '../services/session_service'
require_relative '../../lib/security_log'

msg_key = ENV.fetch('MSG_KEY') do
  raise 'MSG_KEY is missing. Add MSG_KEY to your .env file (Base64-encoded NaCl key).'
end
SecureMessage.setup(msg_key)
