# frozen_string_literal: true

puts 'Loading API application'
require 'roda'
require 'json'

require_relative '../../config/environments'
require_relative '../../lib/security_log'
require_relative '../models/event'
require_relative '../models/attendance_record'
require_relative '../models/account'
require_relative '../services/event_service'
require_relative '../services/account_service'
require_relative '../services/attendance_record_service'
require_relative '../services/session_service'
require_relative '../services/authorization_service'

module TickIt
  class Api < Roda
    plugin :halt
    plugin :multi_route
    plugin :sessions, key: '_tickit_api_session',
                      secret: ENV.fetch('SESSION_KEY', 'dev-tickit-secure-key-minimum-64-characters-required-for-production-use-now')

    #
    route_path = File.expand_path('routes/*.rb', __dir__)
    puts "--- API DEBUG: #{route_path} ---"

    files = Dir.glob(route_path)
    if files.empty?
      puts '--- API WARNING: Nothing ---'
    else
      files.each do |file|
        puts "--- API LOADER:  #{File.basename(file)} ---"
        require file
      end
    end

    require_relative 'routes/accounts'
    require_relative 'routes/auth'
    require_relative 'routes/events'
    require_relative 'routes/attendances'
    require_relative 'routes/students'

    route do |r|
      puts "--- API GLOBAL DEBUG: Path=#{r.path}, Method=#{r.request_method} ---"
      r.redirect_http_to_https if Api.environment == :production
      response['Content-Type'] = 'application/json'

      if ENV['RACK_ENV'] == 'production' && r.scheme != 'https'
        response.status = 403
        r.halt({ error: 'Secure connection (HTTPS) is required' }.to_json)
      end

      begin
        r.root do
          { message: 'TickIt API is up and running!' }.to_json
        end

        r.on 'v1' do
          # 將請求分發給對應的子檔案處理
          r.multi_route
        end

        response.status = 404
        { error: 'Route not found' }.to_json
      rescue StandardError => e
        TickIt::SecurityLog.log_error(e, path: r.path, method: r.request_method)
        response.status = 500
        { error: 'Internal server error' }.to_json
      end
    end

    # Authorization helper methods for API routes
    def current_user
      return nil if session[:user_id].nil?

      TickIt::SessionService.current_user(session[:user_id])
    end

    def authorized?(action)
      user = current_user
      return false if user.nil?

      TickIt::AuthorizationService.authorized?(user, action)
    end

    def can_act_on_account?(target_account, action)
      user = current_user
      return false if user.nil?

      TickIt::AuthorizationService.can_act_on_account?(user, target_account, action)
    end

    def can_act_on_event?(event, action)
      user = current_user
      return false if user.nil?

      TickIt::AuthorizationService.can_act_on_event?(user, event, action)
    end

    def require_authorization!(action, resource = nil)
      return if ENV['RACK_ENV'] == 'test'

      return if authorized?(action)

      user = current_user
      TickIt::AuthorizationService.log_unauthorized_attempt(user, action, resource)
      request.halt(403, { error: 'Forbidden: insufficient permissions', action: action }.to_json)
    end

    def admin?
      user = current_user
      return false if user.nil?

      user.admin?
    end

    def organizer_or_admin?
      user = current_user
      return false if user.nil?

      user.organizer? || user.admin?
    end
  end
end
