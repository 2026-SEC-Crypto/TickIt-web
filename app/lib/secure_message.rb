# frozen_string_literal: true

require 'rbnacl'
require 'base64'
require 'json'

# Library to encrypt and decrypt messages using NaCl's SimpleBox
# It uses authenticated encryption to ensure data cannot be read or tampered with
class SecureMessage
  class << self
    attr_reader :key

    # Setup the secret key from environment variables
    # The key must be a Base64 encoded string
    def setup(msg_key)
      @key = Base64.strict_decode64(msg_key)
    end

    # Encrypt a Ruby object (e.g., Hash, Array) into an encrypted Base64 string
    def encrypt(message)
      return nil unless message

      message_json = message.to_json
      box = RbNaCl::SimpleBox.from_secret_key(@key)

      # Authenticated encryption happens here
      ciphertext = box.encrypt(message_json)
      Base64.urlsafe_encode64(ciphertext)
    end

    # Decrypt a Base64 string back into a Ruby object
    def decrypt(ciphertext64)
      return nil unless ciphertext64

      ciphertext = Base64.urlsafe_decode64(ciphertext64)
      box = RbNaCl::SimpleBox.from_secret_key(@key)

      # Decrypt and parse JSON back to original structure
      message_json = box.decrypt(ciphertext)
      JSON.parse(message_json)
    rescue StandardError
      nil
    end
  end
end
