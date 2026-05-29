# frozen_string_literal: true

require 'roda'
require 'json'
require_relative '../lib/bootstrap'
require_relative '../services/fetch_policy_summary'

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
      use Rack::Session::Redis,
          redis_server: ENV.fetch('REDISCLOUD_URL', 'redis://localhost:6379/0'),
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

    TW_DAYS = %w[日 一 二 三 四 五 六].freeze

    def to_iso8601(val)
      return nil if val.to_s.strip.empty?

      str = val.to_s.strip
      # If no timezone info, treat as Taiwan local time (UTC+8)
      str = "#{str}+08:00" unless str.match?(/Z$|[+-]\d{2}:\d{2}$/)
      # Always return as UTC to avoid ambiguity
      Time.parse(str).utc.iso8601
    rescue ArgumentError
      nil
    end

    def to_datetime_local_tw(time_str)
      return '' if time_str.nil? || time_str.to_s.strip.empty?

      Time.parse(time_str.to_s).localtime('+08:00').strftime('%Y-%m-%dT%H:%M')
    rescue ArgumentError
      ''
    end

    def format_time_tw(time_str)
      return '—' if time_str.nil? || time_str.to_s.strip.empty?

      t = Time.parse(time_str.to_s).localtime('+08:00')
      day = TW_DAYS[t.wday]
      t.strftime("%Y-%m-%d（#{day}）%H:%M")
    rescue ArgumentError
      time_str.to_s
    end

    def teacher_or_admin?
      return false if @current_user.nil?

      @current_user.teacher? || @current_user.admin?
    end

    def make_authorization_available
      @is_admin = admin?
      @is_teacher_or_admin = teacher_or_admin?
      @user_role = @current_user&.role || 'guest'
      @policy_summary = session[:policy_summary] || {}
    end

    def establish_session(user)
      @current_session.save(user)
      @current_user = user
      # Fetch and store policy summary for this user
      begin
        summary = TickIt::FetchPolicySummary.new(token: user.auth_token).call
        session[:policy_summary] = summary['policies'] || {}
      rescue StandardError
        session[:policy_summary] = {}
      end
      @policy_summary = session[:policy_summary]
    end

    def clear_session!
      @current_session.clear!
      @current_user = nil
    end

    route do |r|
      r.redirect_http_to_https if Web.environment == :production

      @secure_session = SecureSession.new(session)
      @current_session = CurrentSession.new(@secure_session)
      @current_user = @current_session.load
      @flash = flash
      make_authorization_available

      r.root { r.redirect '/home' }

      r.get 'home' do
        # Refresh policy summary if logged in
        if @current_user
          begin
            summary = TickIt::FetchPolicySummary.new(token: @current_user.auth_token).call
            session[:policy_summary] = summary['policies'] || {}
          rescue StandardError
            session[:policy_summary] = {}
          end
          @policy_summary = session[:policy_summary]
        end
        render_with_layout 'homes/home'
      end

      r.on 'login' do
        r.get do
          if @current_user
            r.redirect '/account'
          else
            render_with_layout 'sessions/login'
          end
        end

        r.post do
          form = LoginForm.new.call(r.params)

          unless form.success?
            response.status = 400
            @error = form.errors.to_h.values.flatten.first
            return render_with_layout 'sessions/login'
          end

          begin
            user = AuthenticateAccount.new.call(
              email: form.values[:email],
              password: form.values[:password]
            )
          rescue AuthenticateAccount::Error => e
            response.status = 503
            flash['error'] = e.message
            return render_with_layout 'sessions/login'
          end

          if user
            establish_session(user)
            SessionService.log_user_action(user.id, 'login')
            flash['notice'] = "Welcome back, #{user.username || user.email}!"
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
          form = RegisterForm.new.call(r.params)

          unless form.success?
            response.status = 400
            @error = form.errors.to_h.values.flatten.first
            return render_with_layout 'sessions/register_initial'
          end

          begin
            token = RegistrationToken.generate(form.values[:username], form.values[:email])
            verification_url = "#{request.base_url}/verify_registration?token=#{token}"
          rescue StandardError => e
            response.status = 500
            @error = "Failed to generate verification token: #{e.message}"
            return render_with_layout 'sessions/register_initial'
          end

          begin
            EmailService.new.send_verification_email(form.values[:email], verification_url)
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
          form = SetPasswordForm.new.call(r.params)

          unless form.success?
            response.status = 400
            @error = form.errors.to_h.values.flatten.first
            return render_with_layout 'sessions/set_password'
          end

          pending_registration = session[:pending_registration] || {
            username: r.params['username'],
            email: r.params['email']
          }

          if pending_registration[:email].nil? || pending_registration[:email].empty?
            flash['error'] = 'Session expired. Please register again.'
            return r.redirect '/register'
          end

          begin
            CreateAccount.new.call(
              email: pending_registration[:email],
              password: form.values[:password],
              username: pending_registration[:username]
            )

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
          unless @current_user
            response.status = 403
            flash['error'] = 'You must be logged in to access your account'
            return r.redirect '/login'
          end

          begin
            user = FetchAccount.new(token: @current_user.auth_token).call(id: @current_user.id)
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

          # Refresh policy summary for account page
          begin
            summary = TickIt::FetchPolicySummary.new(token: @current_user.auth_token).call
            session[:policy_summary] = summary['policies'] || {}
          rescue StandardError
            session[:policy_summary] = {}
          end
          @policy_summary = session[:policy_summary]

          begin
            @events = FetchEvents.new(token: @current_user.auth_token).call
          rescue FetchEvents::Error
            @events = []
          end

          render_with_layout 'accounts/overview'
        end
      end

      r.on 'events' do
        unless @current_user
          flash['error'] = 'You must be logged in to view events'
          r.redirect '/login'
        end

        r.get 'new' do
          unless @is_teacher_or_admin
            flash['error'] = 'Only teachers and admins can create events'
            return r.redirect '/events'
          end

          render_with_layout 'events/new'
        end

        r.on String do |event_id|
          r.get 'edit' do
            unless @is_teacher_or_admin
              flash['error'] = 'Only teachers and admins can edit events'
              return r.redirect "/events/#{event_id}"
            end

            begin
              result   = FetchEvent.new(token: @current_user.auth_token).call(id: event_id)
              @event   = result[:event]
              @policy  = result[:policy]
            rescue FetchEvent::NotFound
              flash['error'] = 'Event not found'
              return r.redirect '/events'
            end

            now             = Time.now
            start_t         = @event.start_time ? Time.parse(@event.start_time) : nil
            end_t           = @event.end_time   ? Time.parse(@event.end_time)   : nil
            @event_started  = start_t && now >= start_t
            @event_ended    = end_t   && now >= end_t

            # If stored attendance times are outside the event range (e.g. old corrupted timezone data),
            # reset the prefill values to the event start/end times.
            att_s = @event.attendance_start_time ? Time.parse(@event.attendance_start_time) : nil
            att_e = @event.attendance_end_time   ? Time.parse(@event.attendance_end_time)   : nil
            if start_t && end_t && att_s && att_e && (att_s < start_t || att_e > end_t)
              @att_start_prefill = @event.start_time
              @att_end_prefill   = @event.end_time
            else
              @att_start_prefill = @event.attendance_start_time
              @att_end_prefill   = @event.attendance_end_time
            end

            render_with_layout 'events/edit'
          end

          r.post 'delete' do
            unless @is_teacher_or_admin
              flash['error'] = 'Only teachers and admins can delete events'
              return r.redirect "/events/#{event_id}"
            end

            begin
              DeleteEvent.new(token: @current_user.auth_token).call(id: event_id)
              flash['notice'] = 'Event deleted successfully.'
              r.redirect '/events'
            rescue DeleteEvent::Forbidden
              flash['error'] = 'You do not have permission to delete this event'
              r.redirect "/events/#{event_id}"
            rescue DeleteEvent::NotFound
              flash['error'] = 'Event not found'
              r.redirect '/events'
            end
          end

          r.post do
            unless @is_teacher_or_admin
              flash['error'] = 'Only teachers and admins can edit events'
              return r.redirect "/events/#{event_id}"
            end

            now = Time.now
            begin
              result  = FetchEvent.new(token: @current_user.auth_token).call(id: event_id)
              event   = result[:event]
            rescue FetchEvent::NotFound
              flash['error'] = 'Event not found'
              return r.redirect '/events'
            end

            start_t       = event.start_time ? Time.parse(event.start_time) : nil
            end_t         = event.end_time   ? Time.parse(event.end_time)   : nil
            event_started = start_t && now >= start_t
            event_ended   = end_t   && now >= end_t

            fields = {}
            unless event_ended
              unless event_started
                fields[:start_time] = to_iso8601(r.params['start_time'])
              end
              fields[:name]     = r.params['name']
              fields[:location] = r.params['location']
              fields[:end_time] = to_iso8601(r.params['end_time'])
            end
            effective_start = fields[:start_time] || event.start_time
            effective_end   = fields[:end_time]   || event.end_time
            fields[:attendance_start_time] = to_iso8601(r.params['attendance_start_time']) || effective_start
            fields[:attendance_end_time]   = to_iso8601(r.params['attendance_end_time'])   || effective_end
            fields[:description] = r.params['description']

            if effective_start && effective_end &&
               fields[:attendance_start_time] && fields[:attendance_end_time]
              s  = Time.parse(effective_start.to_s)
              e  = Time.parse(effective_end.to_s)
              as = Time.parse(fields[:attendance_start_time].to_s)
              ae = Time.parse(fields[:attendance_end_time].to_s)

              if as < s || ae > e
                flash['error'] = 'Attendance window must be within the event start and end time.'
                next r.redirect "/events/#{event_id}/edit"
              end
            end

            begin
              UpdateEvent.new(token: @current_user.auth_token).call(id: event_id, **fields)
              flash['notice'] = 'Event updated successfully!'
              r.redirect "/events/#{event_id}"
            rescue UpdateEvent::InvalidEvent => e
              response.status = 400
              flash['error'] = e.message
              r.redirect "/events/#{event_id}/edit"
            rescue UpdateEvent::Forbidden
              flash['error'] = 'You do not have permission to edit this event'
              r.redirect "/events/#{event_id}"
            end
          end

          r.get do
            begin
              result     = FetchEvent.new(token: @current_user.auth_token).call(id: event_id)
              @event     = result[:event]
              @attendees = result[:attendees]
              @policy    = result[:policy]
            rescue FetchEvent::NotFound
              flash['error'] = 'Event not found'
              return r.redirect '/events'
            end

            render_with_layout 'events/show'
          end
        end

        r.get do
          begin
            @events = FetchEvents.new(token: @current_user.auth_token).call
          rescue FetchEvents::Error
            @events = []
          end

          render_with_layout 'events/index'
        end

        r.post do
          unless @is_teacher_or_admin
            flash['error'] = 'Only teachers and admins can create events'
            return r.redirect '/events'
          end

          start_time     = to_iso8601(r.params['start_time'])
          end_time       = to_iso8601(r.params['end_time'])
          att_start      = to_iso8601(r.params['attendance_start_time']) || start_time
          att_end        = to_iso8601(r.params['attendance_end_time'])   || end_time

          if start_time && end_time && att_start && att_end
            s  = Time.parse(start_time)
            e  = Time.parse(end_time)
            as = Time.parse(att_start)
            ae = Time.parse(att_end)

            if as < s || ae > e
              response.status = 400
              @error = 'Attendance window must be within the event start and end time.'
              next render_with_layout 'events/new'
            end
          end

          begin
            CreateEvent.new(token: @current_user.auth_token).call(
              name: r.params['name'],
              location: r.params['location'],
              start_time: start_time,
              end_time: end_time,
              attendance_start_time: att_start,
              attendance_end_time: att_end,
              description: r.params['description']
            )
            flash['notice'] = 'Event created successfully!'
            r.redirect '/events'
          rescue CreateEvent::InvalidEvent => e
            response.status = 400
            @error = e.message
            render_with_layout 'events/new'
          rescue CreateEvent::Forbidden
            flash['error'] = 'You do not have permission to create events'
            r.redirect '/events'
          end
        end

      end

      r.on 'logout' do
        SessionService.log_user_action(@current_user.id, 'logout') if @current_user

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
