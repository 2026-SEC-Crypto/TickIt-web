require_relative 'secure_message'

# Library to handle registration token generation and verification
class RegistrationToken
  TOKEN_EXPIRY = 3600 # 1 hour in seconds

  # Generate a token with username, email, and expiry
  def self.generate(username, email)
    payload = {
      username: username,
      email: email,
      exp: Time.now.to_i + TOKEN_EXPIRY # Add expiry time
    }
    SecureMessage.encrypt(payload) # Encrypt the payload
  end

  # Decode a token and verify its validity
  def self.decode(token)
    return nil unless token

    payload = SecureMessage.decrypt(token) # Decrypt the token
    return nil if payload.nil?
    
    # Check expiry using string key (JSON uses string keys, not symbols)
    exp_time = payload['exp'] || payload[:exp]
    return nil if exp_time.nil?
    return nil if exp_time < Time.now.to_i # Check if the token is expired

    payload # Return the valid payload
  rescue StandardError
    nil # Return nil if decryption fails or token is invalid
  end
end