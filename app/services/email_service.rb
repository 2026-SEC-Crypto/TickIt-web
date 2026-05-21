# frozen_string_literal: true

require 'mailgun-ruby'

class EmailService
  def initialize
    @api_key = ENV.fetch('MAILGUN_API_KEY', nil)
    @domain = ENV.fetch('MAILGUN_DOMAIN', nil)
    @sender = ENV.fetch('MAILGUN_SENDER', 'noreply@tickit.local')
    @client = Mailgun::Client.new(@api_key) if @api_key
  end

  def send_verification_email(email, verification_url)
    raise 'Mailgun API key not configured' unless @api_key
    raise 'Mailgun domain not configured' unless @domain

    message_params = {
      from: @sender,
      to: email,
      subject: 'Verify Your Email Address for TickIt',
      html: build_html_email(verification_url),
      text: build_text_email(verification_url)
    }

    @client.send_message(@domain, message_params)
  rescue StandardError => e
    raise "Failed to send verification email: #{e.message}"
  end

  private

  def build_html_email(verification_url)
    <<~HTML
      <html>
        <body>
          <h2>Verify Your Email Address</h2>
          <p>Thank you for registering with TickIt!</p>
          <p>Please click the link below to verify your email address and complete your registration:</p>
          <p><a href="#{verification_url}">Verify Email</a></p>
          <p>Or copy and paste this link into your browser:</p>
          <p>#{verification_url}</p>
          <p>This link will expire in 1 hour.</p>
          <p>If you did not register for TickIt, you can safely ignore this email.</p>
        </body>
      </html>
    HTML
  end

  def build_text_email(verification_url)
    <<~TEXT
      Thank you for registering with TickIt!

      Please verify your email by clicking the following link:
      #{verification_url}

      This link will expire in 1 hour.

      If you did not register for TickIt, you can safely ignore this email.
    TEXT
  end
end
