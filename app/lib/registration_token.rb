require_relative 'secure_message'

# Library to handle registration token generation and verification
class RegistrationToken
  TOKEN_EXPIRY = 3600 # 1 hour in seconds

  def self.generate(username, email)
    payload = {
      username: username,
      email: email,
      exp: Time.now.to_i + TOKEN_EXPIRY
    }
    SecureMessage.encrypt(payload)
  end

  def self.decode(token)
    payload = SecureMessage.decrypt(token)
    return nil if payload[:exp] < Time.now.to_i

    payload
  rescue StandardError
    nil
  end
end