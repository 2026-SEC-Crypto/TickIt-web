# frozen_string_literal: true

require 'roda'
require 'json'
require_relative '../lib/bootstrap'

module TickIt
  # Web UI — renders Slim pages and talks to TickIt API over HTTP.
  class Web < Roda
    plugin :render, engine: 'slim', views: 'app/views'
    plugin :flash
    plugin :halt
    plugin :environments
    plugin :common_logger, $stderr

    SESSION_SECRET = ENV.fetch(
      'SESSION_KEY',
      'dev-tickit-secure-key-minimum-64-characters-required-for-production-use-now'
    ).freeze

    configure :production do
      plugin :redirect_http_to_https
      plugin :hsts
    end

    if ENV.fetch('RACK_ENV', 'development') == 'production'
      require 'redis'
      require 'rack/session/redis'
      ENV.fetch('REDISCLOUD_URL', 'redis://localhost:6379/0')
      plugin :sessions,
             key: '_tickit_web_session',
             secret: SESSION_SECRET,
             expire_after: 2_592_000
    else
      plugin :sessions,
             key: '_tickit_web_session',
             secret: SESSION_SECRET,
             expire_after: 2_592_000
    end

    def render_with_layout(view_name)
      @flash = flash
      view(view_name, layout: 'layouts/layout')
    end

    def authorized?(action)
      return false if @current_user.nil?

      AuthorizationService.authorized?(@current_user, action)
    end

    def can_act_on_account?(target_account, action)
      return false if @current_user.nil?

      AuthorizationService.can_act_on_account?(@current_user, target_account, action)
    end

    def admin?
      @current_user&.admin? || false
    end

    def organizer_or_admin?
      return false if @current_user.nil?

      @current_user.organizer? || @current_user.admin?
    end

    def make_authorization_available
      @is_admin = admin?
      @is_organizer_or_admin = organizer_or_admin?
      @user_role = @current_user&.role || 'guest'
    end

    def establish_session(user)
      @secure_session.set(:account_id, user.id)
      @secure_session.set(:email, user.email)
      @secure_session.set(:role, user.role)
      @current_user = user
    end

    def load_current_user_from_session
      account_id = @secure_session.get(:account_id)
      return nil unless account_id

      SessionUser.new(
        id: account_id,
        email: @secure_session.get(:email),
        role: @secure_session.get(:role) || 'member'
      )
    end

    def clear_session!
      @secure_session.delete(:account_id)
      @secure_session.delete(:email)
      @secure_session.delete(:role)
      @current_user = nil
    end

    route do |r|
      r.redirect_http_to_https if Web.environment == :production

      @secure_session = SecureSession.new(session)
      @current_user = load_current_user_from_session
      @flash = flash
      make_authorization_available

      r.root { r.redirect '/home' }

      r.get 'home' do
        render_with_layout 'homes/home'
      end

      r.on 'login' do
        r.get do
          if @secure_session.get(:account_id)
            r.redirect '/account'
          else
            render_with_layout 'sessions/login'
          end
        end

        r.post do
          email = r.params['email']
          password = r.params['password']

          if email.to_s.strip.empty? || password.to_s.empty?
            response.status = 400
            @error = 'Email and password are required'
            return render_with_layout 'sessions/login'
          end

          begin
            user = AuthenticateAccount.new.call(email: email, password: password)
          rescue AuthenticateAccount::Error => e
            response.status = 503
            flash['error'] = e.message
            return render_with_layout 'sessions/login'
          end

          if user
            establish_session(user)
            SessionService.log_user_action(user.id, 'login')
            flash['notice'] = "Welcome back, #{user.email}!"
            flash['error'] = nil
            r.redirect '/account'
          else
            response.status = 401
            @error = 'Invalid email or password'
            render_with_layout 'sessions/login'
          end
        end
      end

      # Registration workflow: 1. User enters email/username -> 2. Verification email sent -> 3. User clicks link -> 4. Sets password
      r.on 'register' do
        r.get do
          # Show registration form asking for email and username
          render_with_layout 'sessions/register_initial'
        end

        r.post do
          username = r.params['username']
          email = r.params['email']

          # Validate input
          if username.to_s.strip.empty? || email.to_s.strip.empty?
            response.status = 400
            @error = 'Username and email are required'
            return render_with_layout 'sessions/register_initial'
          end

          # Generate verification token
          begin
            token = RegistrationToken.generate(username, email)
            verification_url = "#{request.base_url}/verify_registration?token=#{token}"
          rescue StandardError => e
            response.status = 500
            @error = "Failed to generate verification token: #{e.message}"
            return render_with_layout 'sessions/register_initial'
          end

          # Send verification email
          begin
            EmailService.new.send_verification_email(email, verification_url)
          rescue StandardError => e
            response.status = 500
            @error = "Failed to send verification email: #{e.message}"
            return render_with_layout 'sessions/register_initial'
          end

          flash['notice'] = 'Verification email sent! Please check your inbox and click the verification link.'
          r.redirect '/home'
        end
      end

      # Handle email verification link click
      r.on 'verify_registration' do
        r.get do
          token = r.params['token']

          # Decode and validate token
          payload = RegistrationToken.decode(token)

          unless payload
            response.status = 401
            flash['error'] = 'Invalid or expired verification link. Please register again.'
            return r.redirect '/register'
          end

          # Store temporarily in session (will be cleared after password set)
          session[:pending_registration] = {
            username: payload['username'],
            email: payload['email']
          }

          # Show password entry form
          render_with_layout 'sessions/set_password'
        end
      end

      # Handle password entry after email verification
      r.on 'set_password' do
        r.post do
          password = r.params['password']
          password_confirm = r.params['password_confirm']

          # Validate input
          if password.to_s.strip.empty? || password_confirm.to_s.strip.empty?
            response.status = 400
            @error = 'Passwords cannot be empty'
            return render_with_layout 'sessions/set_password'
          end

          if password != password_confirm
            response.status = 400
            @error = 'Passwords do not match'
            return render_with_layout 'sessions/set_password'
          end

          # Retrieve pending registration from session or form params (fallback)
          pending_registration = session[:pending_registration] || {
            username: r.params['username'],
            email: r.params['email']
          }
          
          if pending_registration[:email].nil? || pending_registration[:email].empty?
            flash['error'] = 'Session expired. Please register again.'
            return r.redirect '/register'
          end

          # Create account through API
          begin
            user = CreateAccount.new.call(
              email: pending_registration[:email],
              password: password
            )

            # Clear session
            session[:pending_registration] = nil

            flash['notice'] = 'Account created successfully! Please log in.'
            r.redirect '/login'
          rescue CreateAccount::InvalidAccount => e
            response.status = 400
            @error = "Account creation failed: #{e.message}"
            render_with_layout 'sessions/set_password'
          end
        end
      end

      r.on 'account' do
        r.get do
          unless @secure_session.get(:account_id)
            response.status = 403
            flash['error'] = 'You must be logged in to access your account'
            return r.redirect '/login'
          end

          begin
            user = FetchAccount.new.call(id: @secure_session.get(:account_id))
            establish_session(user)
            make_authorization_available
          rescue FetchAccount::NotFound
            clear_session!
            response.status = 403
            flash['error'] = 'Your session has expired. Please log in again.'
            return r.redirect '/login'
          rescue FetchAccount::Error => e
            response.status = 503
            flash['error'] = e.message
            return r.redirect '/login'
          end

          render_with_layout 'accounts/overview'
        end
      end

      r.on 'logout' do
        account_id = @secure_session.get(:account_id)
        SessionService.log_user_action(account_id, 'logout') if account_id

        clear_session!
        flash['notice'] = 'You have been successfully logged out. See you soon!'
        r.redirect '/home'
      end

      response.status = 404
      @error = 'Page not found'
      render_with_layout 'errors/not_found'
    end
  end
end
