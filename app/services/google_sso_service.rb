# frozen_string_literal: true

require 'http'
require 'jwt'
require 'uri'

require_relative 'api_client'

module TickIt
  class GoogleSsoService < ApiClient
    class ConfigurationError < StandardError; end
    class StateMismatch < StandardError; end
    class VerificationError < StandardError; end
    class TokenExchangeError < StandardError; end
    class ApiError < StandardError; end

    DISCOVERY_URL = 'https://accounts.google.com/.well-known/openid-configuration'
    ISSUERS = ['https://accounts.google.com', 'accounts.google.com'].freeze
    DEFAULT_SCOPE = 'openid email profile'.freeze

    def self.configured?
      ENV['GOOGLE_CLIENT_ID'].to_s.strip != '' && ENV['GOOGLE_CLIENT_SECRET'].to_s.strip != ''
    end

    def client_id
      ENV.fetch('GOOGLE_CLIENT_ID')
    end

    def client_secret
      ENV.fetch('GOOGLE_CLIENT_SECRET')
    end

    def scope
      ENV.fetch('GOOGLE_OAUTH_SCOPE', DEFAULT_SCOPE)
    end

    def discovery_document
      response = HTTP.get(DISCOVERY_URL)
      raise ConfigurationError, 'Could not load Google discovery document' unless response.status == 200

      parse_json(response.body)
    rescue HTTP::Error => e
      raise ConfigurationError, "Could not reach Google discovery endpoint: #{e.message}"
    end

    def authorization_url(redirect_uri:, state:, nonce:)
      endpoint = discovery_document.fetch('authorization_endpoint')
      params = {
        client_id: client_id,
        redirect_uri: redirect_uri,
        response_type: 'code',
        scope: scope,
        state: state,
        nonce: nonce,
        prompt: 'select_account'
      }

      "#{endpoint}?#{URI.encode_www_form(params)}"
    end

    def authenticate(code:, redirect_uri:, state:, expected_state:, nonce:)
      raise StateMismatch, 'Google SSO state mismatch' if state.to_s.empty? || state != expected_state

      token_body = exchange_code_for_tokens(code: code, redirect_uri: redirect_uri)
      id_token = token_body.fetch('id_token')
      claims = verify_id_token(id_token, nonce: nonce)
      authenticate_with_api(id_token: id_token, claims: claims)
    end

    def exchange_code_for_tokens(code:, redirect_uri:)
      response = HTTP.headers('Content-Type' => 'application/x-www-form-urlencoded').post(
        discovery_document.fetch('token_endpoint'),
        form: {
          code: code,
          client_id: client_id,
          client_secret: client_secret,
          redirect_uri: redirect_uri,
          grant_type: 'authorization_code'
        }
      )

      case response.status
      when 200
        parse_json(response.body)
      else
        raise TokenExchangeError,
              error_message(response.body, "Google token exchange failed (status: #{response.status})")
      end
    rescue HTTP::Error => e
      raise TokenExchangeError, "Could not reach Google token endpoint: #{e.message}"
    end

    def verify_id_token(id_token, nonce:)
      jwks = JWT::JWK::Set.new(
        fetch_jwks.fetch('keys').map { |key| JWT::JWK.import(key) }
      )

      claims, = JWT.decode(
        id_token,
        nil,
        true,
        algorithms: ['RS256'],
        jwks: jwks,
        verify_iss: true,
        iss: ISSUERS,
        verify_aud: true,
        aud: client_id
      )

      raise VerificationError, 'Google SSO nonce mismatch' if claims['nonce'].to_s != nonce.to_s

      claims
    rescue JWT::DecodeError, JWT::VerificationError => e
      raise VerificationError, "Invalid Google id_token: #{e.message}"
    end

    def fetch_jwks
      response = HTTP.get(discovery_document.fetch('jwks_uri'))
      raise VerificationError, 'Could not load Google JWKS' unless response.status == 200

      parse_json(response.body)
    rescue HTTP::Error => e
      raise VerificationError, "Could not reach Google JWKS endpoint: #{e.message}"
    end

    def authenticate_with_api(id_token:, claims:)
      response = http_client.post(
        "#{api_url}/auth/sso",
        json: {
          provider: 'google',
          id_token: id_token,
          claims: claims
        }
      )

      case response.status
      when 200, 201
        body = parse_json(response.body)
        account_data = body.fetch('account', {})
        account_data['username'] ||= claims['name'] || claims['email']&.split('@')&.first
        account_data['email'] ||= claims['email']
        account_data['avatar_url'] ||= claims['picture']
        Account.from_api_hash(account_data, fallback: claims)
      else
        raise ApiError, error_message(response.body, "Google SSO failed (status: #{response.status})")
      end
    rescue HTTP::Error => e
      raise ApiError, "Could not reach API: #{e.message}"
    end
  end
end