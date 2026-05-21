require 'mailgun-ruby'

class EmailService
  def initialize
    @api_key = ENV['MAILGUN_API_KEY']
    @domain = ENV['MAILGUN_DOMAIN']
    @client = Mailgun::Client.new(@api_key)
  end

  def send_verification_email(email, verification_url)
    message_params = {
      from: 'no-reply@yourdomain.com',
      to: email,
      subject: 'Verify Your Email Address',
      text: "Please verify your email by clicking the following link: #{verification_url}"
    }

    @client.send_message(@domain, message_params)
  end
end