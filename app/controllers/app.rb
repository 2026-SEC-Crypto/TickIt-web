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

      r.on 'register' do
        r.get do
          if @secure_session.get(:account_id)
            r.redirect '/account'
          else
            render_with_layout 'sessions/register'
          end
        end

        r.post do
          email = r.params['email']
          password = r.params['password']
          password_confirm = r.params['password_confirm']

          if email.to_s.strip.empty?
            response.status = 400
            @error = 'Email is required'
            return render_with_layout 'sessions/register'
          end

          if password.to_s.empty?
            response.status = 400
            @error = 'Password is required'
            return render_with_layout 'sessions/register'
          end

          if password != password_confirm
            response.status = 400
            @error = 'Passwords do not match'
            return render_with_layout 'sessions/register'
          end

          begin
            user = CreateAccount.new.call(email: email, password: password)
          rescue CreateAccount::InvalidAccount => e
            response.status = e.message.include?('already exists') ? 409 : 400
            @error = e.message
            return render_with_layout 'sessions/register'
          end

          establish_session(user)
          SessionService.log_user_action(user.id, 'register')
          flash['notice'] = 'Account created successfully! Welcome to TickIt.'
          flash['error'] = nil
          r.redirect '/account'
        end
      end

      r.on 'register_initial' do
        r.post do
          username = r.params['username']
          email = r.params['email']

          begin
            create_account_service = CreateAccount.new

            unless create_account_service.check_availability(username: username, email: email)
              flash[:error] = 'Username or email is already taken.'
              r.redirect '/register_initial'
            end

            verification_url = create_account_service.generate_verification_url(username: username, email: email)

            # Mock sending email (to be implemented later)
            puts "Verification email sent to #{email} with URL: #{verification_url}"

            flash[:notice] = 'A verification email has been sent. Please check your inbox.'
            r.redirect '/'
          rescue CreateAccount::InvalidAccount => e
            flash[:error] = e.message
            r.redirect '/register_initial'
          end
        end
      end

      r.on 'verify_registration' do
        token = r.params['token']
        payload = RegistrationToken.decode(token)

        if payload
          session[:pending_registration] = payload
          render_with_layout 'sessions/register'
        else
          flash[:error] = 'Invalid or expired verification link.'
          r.redirect '/'
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
