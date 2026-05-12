# frozen_string_literal: true

require 'roda'
require 'figaro'
require 'sequel'
require_relative '../lib/secure_db'
require_relative '../lib/security_log'

module TickIt
  # Configuration for the API
  class Api < Roda
    plugin :environments
    configure :production do
      plugin :redirect_http_to_https
      plugin :hsts
    end

    # load config secrets into local environment variables (ENV)
    # FIGARO_SECRETS_PATH may point to a temp file in tests (e.g. missing DATABASE_URL check)
    secrets_path = ENV.fetch('FIGARO_SECRETS_PATH', File.expand_path('config/secrets.yml'))
    Figaro.application = Figaro::Application.new(
      environment: environment,
      path: secrets_path
    )
    Figaro.load

    # Make the environment variables accessible to other classes
    def self.config
      Figaro.env
    end

    # Connect and make the database accessible to other classes
    db_url = ENV.delete('DATABASE_URL')
    if db_url.nil? || db_url.strip.empty?
      raise 'DATABASE_URL is missing. Copy config/secrets-example.yml to config/secrets.yml and set DATABASE_URL.'
    end

    DB = Sequel.connect("#{db_url}?encoding=utf8", pool_class: :threaded, max_connections: 5)
    def self.DB # rubocop:disable Naming/MethodName
      DB
    end

    configure :development, :production do
      plugin :common_logger, $stderr
    end

    configure :development, :test do
      require 'pry'
      DB.pool.connection_validation_frequency = 900  # Validate connections every 15 minutes
      use Rack::Session::Pool, expire_after: ONE_MONTH
    end

    configure :production do
      require 'redis'
      require 'redis-session-store'
      redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
      use RedisSessionStore, 
          redis_server: redis_url,
          expire_after: ONE_MONTH
    end
  end
end
