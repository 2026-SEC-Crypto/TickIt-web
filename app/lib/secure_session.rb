# frozen_string_literal: true

# Proxy class to manage encrypted data storage within the session
# It sits between our code and the real Roda session
class SecureSession
  def initialize(session)
    @session = session
  end

  # Encrypt a value and store it in the session
  def set(key, value)
    @session[key] = SecureMessage.encrypt(value)
  end

  # Retrieve an encrypted value from the session and decrypt it
  def get(key)
    SecureMessage.decrypt(@session[key])
  end

  # Remove a key from the session
  def delete(key)
    @session.delete(key)
  end
end
