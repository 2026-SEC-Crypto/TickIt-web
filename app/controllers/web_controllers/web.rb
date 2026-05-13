# frozen_string_literal: true

require 'roda'
require 'json'

require_relative '../../models/account'
require_relative '../../services/account_service'
require_relative '../../services/session_service'
require_relative '../../services/authorization_service'
require_relative '../../../config/environments'
require_relative '../../../lib/security_log'
require_relative '../../services/create_account'
require 'dotenv'
require_relative '../../lib/secure_message'
require_relative '../../lib/secure_session'

Dotenv.load # This loads the variables from your .env file into ENV

SecureMessage.setup(ENV.fetch('MSG_KEY'))

module TickIt
  # Web controller for handling user-facing pages and authentication
  # Uses Roda framework with Slim templating engine and secure HTTP-only cookie sessions
  #
  # Plugins Used:
  # - :render - Slim template engine rendering
  # - :sessions - Encrypted HTTP-only cookie session storage
  # - :flash - One-time temporary messages across redirects
  # - :halt - Error handling and response control
  #
  # HTTP Status Codes Used:
  # - 200 OK: Successful request (forms displayed, account page shown)
  # - 400 Bad Request: Validation errors (missing fields, mismatched passwords, invalid input)
  # - 401 Unauthorized: Authentication failure (incorrect email/password)
  # - 403 Forbidden: Access denied (user not logged in or session invalid)
  # - 404 Not Found: Page not found
  # - 409 Conflict: Resource conflict (email already exists during registration)
  #
  class Web < Roda
    plugin :render, engine: 'slim', views: 'app/views'
    plugin :flash
    plugin :halt
    plugin :environments
    plugin :common_logger, $stderr
    # plugin :route_csrf, csrf_failure: :halt

    configure :production do
      plugin :redirect_http_to_https
      plugin :hsts
    end

    # Configure sessions based on environment with pooling strategy
    # Development/Test: Use in-memory session pool
    # Production: Use Redis for distributed sessions
    if ENV.fetch('RACK_ENV', 'development') == 'production'
      require 'redis'
      require 'rack/session/redis'
      redis_url = ENV.fetch('REDISCLOUD_URL', 'redis://localhost:6379/0')
      plugin :sessions,
             key: '_tickit_web_session',
             secret: ENV.fetch('SESSION_KEY', 'dev-session-key-set-in-production'),
             expire_after: TickIt::ONE_MONTH
    else
      # Development/Test: Use in-memory session pool (Rack::Session::Pool)
      use Rack::Session::Pool,
          key: '_tickit_web_session',
          secret: ENV.fetch('SESSION_KEY',
                            'dev-tickit-secure-key-minimum-64-characters-required-for-production-use-now'),
          expire_after: TickIt::ONE_MONTH
      plugin :sessions, key: '_tickit_web_session'
    end

    # Helper to render views with layout
    # All views are rendered with the layout/layout.slim template which includes navigation
    def render_with_layout(view_name)
      view(view_name, layout: 'layouts/layout')
    end

    # Authorization helper methods
    # Check if current user is authorized for an action
    def authorized?(action)
      return false if @current_user.nil?

      AuthorizationService.authorized?(@current_user, action)
    end

    # Check if current user can act on another account
    def can_act_on_account?(target_account, action)
      return false if @current_user.nil?

      AuthorizationService.can_act_on_account?(@current_user, target_account, action)
    end

    # Check if current user is admin
    def admin?
      @current_user&.admin? || false
    end

    # Check if current user is organizer or admin
    def organizer_or_admin?
      return false if @current_user.nil?

      @current_user.organizer? || @current_user.admin?
    end

    # Make authorization helpers available to views
    def make_authorization_available
      @is_admin = admin?
      @is_organizer_or_admin = organizer_or_admin?
      @user_role = @current_user&.role || 'guest'
    end

    route do |r|
      # r.check_csrf
      # Set current user for all requests (for layout navigation)
      # Retrieves account from session if logged in, otherwise nil
      r.redirect_http_to_https if Web.environment == :production
      # 1. Wrap the Roda session with our SecureSession layer
      @secure_session = SecureSession.new(session)

      # 2. Use @secure_session.get instead of reading raw session
      # This will automatically decrypt the data retrieved from the cookie
      account_id = @secure_session.get(:account_id)
      @current_user = account_id ? TickIt::Account.find(id: account_id) : nil

      @flash = flash
      make_authorization_available
      # Make flash messages available to all views
      @flash = flash
      # Make authorization variables available to all views for conditional rendering
      make_authorization_available

      # Redirect to home if accessing root
      r.root do
        r.redirect '/home'
      end

      # Home page
      r.get 'home' do
        render_with_layout 'homes/home'
      end

      # Login page - GET
      # Displays login form; redirects to account page if already logged in
      r.on 'login' do
        r.get do
          if @secure_session.get(:account_id)
            r.redirect '/account'
          else
            render_with_layout 'sessions/login'
          end
        end

        # Login - POST
        # Authenticates user with email and password using AccountService
        # On success: Creates session with user data and redirects to account page
        # On failure: Sets flash error and redisplays form with appropriate status code
        r.post do
          puts '--- DEBUG: Login POST request received ---'
          email = r.params['email']
          password = r.params['password']

          if email.nil? || email.empty? || password.nil? || password.empty?
            response.status = 400 # Bad Request - missing required fields
            flash['error'] = 'Email and password are required'
            return render_with_layout 'sessions/login'
          end

          # begin
          #   api_result = TickIt::CreateAccount.new.call(
          #     email: email,
          #     username: username,
          #     password: password
          #   )
          # rescue TickIt::CreateAccount::InvalidAccount => e
          #   response.status = 400
          #   flash['error'] = "Registration failed: #{e.message}"
          #   return render_with_layout 'sessions/register'
          # rescue StandardError => e
          #   response.status = 500
          #   flash['error'] = 'Server error: Please try again later'
          #   return render_with_layout 'sessions/register'
          # end

          # Call AccountService to authenticate user with encrypted password verification
          account = AccountService.authenticate(email:, password:)
          puts "--- DEBUG: Authentication result: #{account.inspect} ---"
          if account
            puts "--- DEBUG: Login SUCCESS for #{account.email} ---"
            # Create secure session with user information
            # Session data is encrypted and stored in HTTP-only cookie
            @secure_session.set(:account_id, account.id)
            @secure_session.set(:email, account.email)
            @secure_session.set(:role, account.role) # Also encrypt the role!

            # Log successful login to security log
            SessionService.log_user_action(account.id, 'login')
            # Set flash notice for successful login
            flash['notice'] = "Welcome back, #{account.email}!"
            flash['error'] = nil # Clear any previous error
            # Reload current user within same request so account page can use it
            @current_user = account
            make_authorization_available
            # Render account page directly (session will persist through cookie on response)
            render_with_layout 'accounts/overview'
          else
            puts '--- DEBUG: Login FAILED (Invalid credentials) ---'
            response.status = 401 # Unauthorized - invalid credentials
            flash['error'] = 'Invalid email or password'
            return render_with_layout 'sessions/login'
          end
        end
      end

      # Register page - GET
      # Displays registration form; redirects to account page if already logged in
      r.on 'register' do
        r.get do
          if session && session[:account_id]
            r.redirect '/account'
          else
            render_with_layout 'sessions/register'
          end
        end

        # Register - POST
        # Creates new account using AccountService; automatically logs user in on success
        # Validates email uniqueness and password requirements
        r.post do
          email = r.params['email']
          password = r.params['password']
          password_confirm = r.params['password_confirm']

          # Validation
          if email.nil? || email.empty?
            response.status = 400 # Bad Request - missing required field
            flash['error'] = 'Email is required'
            return render_with_layout 'sessions/register'
          end

          if password.nil? || password.empty?
            response.status = 400 # Bad Request - missing required field
            flash['error'] = 'Password is required'
            return render_with_layout 'sessions/register'
          end

          if password != password_confirm
            response.status = 400 # Bad Request - validation error
            flash['error'] = 'Passwords do not match'
            return render_with_layout 'sessions/register'
          end

          # Try to create account using AccountService
          # AccountService handles password encryption via KeyStretching
          # and email encryption/hashing via SecureDB
          begin
            account = AccountService.create_account(email:, password:, role: 'member')
            # Automatically create session for new user
            @secure_session.set(:account_id, account.id)
            @secure_session.set(:email, account.email)
            @secure_session.set(:role, account.role)
            SessionService.log_user_action(account.id, 'register')
            # Set flash notice for successful registration
            flash['notice'] = 'Account created successfully! Welcome to TickIt.'
            flash['error'] = nil # Clear any previous error
            # Reload current user within same request so account page can use it
            @current_user = account
            make_authorization_available
            # Render account page directly (session will persist through cookie on response)
            render_with_layout 'accounts/overview'
          rescue StandardError => e
            # Return 409 Conflict if email already exists, 400 for other validation errors
            response.status = e.message.include?('already exists') ? 409 : 400
            flash['error'] = e.message
            return render_with_layout 'sessions/register'
          end
        end
      end

      # Account overview - requires login
      # Displays user account details; redirects to login if not authenticated
      # Validates session by checking if user still exists in database
      r.on 'account' do
        r.get do
          unless @secure_session.get(:account_id)
            response.status = 403 # Forbidden - not authenticated
            flash['error'] = 'You must be logged in to access your account'
            r.redirect '/login'
          end

          # Validate session by checking if account still exists in database
          # (prevents access if account was deleted after login)
          unless @current_user
            # Clear invalid session data
            @secure_session.delete(:account_id)
            @secure_session.delete(:email)
            @secure_session.delete(:role)
            response.status = 403 # Forbidden - session invalid
            flash['error'] = 'Your session has expired. Please log in again.'
            r.redirect '/login'
          end

          render_with_layout 'accounts/overview'
        end
      end

      # Logout
      # Clears all session data and redirects to home page
      # Session data is stored in encrypted HTTP-only cookie by Roda
      # Deleting session keys effectively clears the cookie
      r.on 'logout' do
        if @secure_session.get(:account_id)
          # Log the logout action for security audit
          SessionService.log_user_action(session[:account_id], 'logout')
        end

        # Delete all account information from session cookie
        # This removes the encrypted data from the HTTP-only cookie
        session.delete(:account_id)
        session.delete(:email)
        session.delete(:role)

        # Set flash message for display on next page
        # Flash messages are automatically cleared after one request
        flash['notice'] = 'You have been successfully logged out. See you soon!'

        # Redirect to home with flash message
        r.redirect '/home'
      end

      # 404
      response.status = 404
      @error = 'Page not found'
      render_with_layout 'errors/not_found'
    end
  end
end
