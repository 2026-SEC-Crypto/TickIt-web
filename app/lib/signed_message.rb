require 'rbnacl'
require 'base64'
require 'json'

module TickIt
  class SignedMessage # rubocop:disable Style/Documentation
    def self.sign(data)
      signing_key = RbNaCl::Signatures::Ed25519::SigningKey.new(
        Base64.strict_decode64(ENV.fetch('SIGNING_KEY'))
      )

      payload = JSON.generate(data)

      signature = signing_key.sign(payload)

      {
        data: data,
        signature: Base64.strict_encode64(signature)
      }
    end
  end
end