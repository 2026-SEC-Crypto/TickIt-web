# frozen_string_literal: true

# Proxy class to manage encrypted data storage within the session.
# Always uses string keys because Roda serializes sessions as JSON (symbols do not round-trip).
class SecureSession
  def initialize(session)
    @session = session
  end

  def set(key, value)
    @session[normalize_key(key)] = SecureMessage.encrypt(value)
  end

  def get(key)
    SecureMessage.decrypt(@session[normalize_key(key)])
  end

  def delete(key)
    @session.delete(normalize_key(key))
  end

  private

  def normalize_key(key)
    key.to_s
  end
end
