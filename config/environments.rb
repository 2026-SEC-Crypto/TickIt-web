# frozen_string_literal: true

require 'figaro'
require 'sequel'
require_relative '../lib/secure_db'
require_relative '../lib/security_log'

module TickIt
  # Load config secrets into local environment variables (ENV)
  # FIGARO_SECRETS_PATH may point to a temp file in tests (e.g. missing DATABASE_URL check)
  secrets_path = ENV.fetch('FIGARO_SECRETS_PATH', File.expand_path('config/secrets.yml'))
  Figaro.application = Figaro::Application.new(
    environment: ENV.fetch('RACK_ENV', 'development'),
    path: secrets_path
  )
  Figaro.load

  # Define time constants
  ONE_MONTH = 60 * 60 * 24 * 30

  # Connect and make the database accessible to all classes
  db_url = ENV.fetch('DATABASE_URL', nil)
  if db_url.nil? || db_url.strip.empty?
    raise 'DATABASE_URL is missing. Set DATABASE_URL environment variable or update config/secrets.yml'
  end

  DB = Sequel.connect("#{db_url}?encoding=utf8", pool_class: :threaded, max_connections: 5)

  def self.DB # rubocop:disable Naming/MethodName
    DB
  end

  def self.config
    Figaro.env
  end

  # Create namespace for backward compatibility with models using TickIt::Api::DB
  module Api
  end
  
  # DB is a constant, make it available as Api::DB
  Api.const_set(:DB, DB)
end
