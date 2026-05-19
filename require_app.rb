# frozen_string_literal: true

def require_app(load_models = nil) # rubocop:disable Metrics/MethodLength
  require 'roda'
  require 'figaro'
  require 'sequel'

  # Load environment
  environment = ENV['RACK_ENV'] || 'development'

  # Load secrets
  Figaro.application = Figaro::Application.new(
    environment: environment,
    path: File.expand_path('config/secrets.yml')
  )
  Figaro.load

  # Load the API class with database connection
  require_relative 'config/environments'

  # Load models if requested
  if load_models == 'models'
    Dir.glob('app/models/*.rb').sort.each { |file| require_relative file }
  end

  # Load services if requested
  if load_models == 'services'
    Dir.glob('app/models/*.rb').sort.each { |file| require_relative file }
    Dir.glob('app/services/*.rb').sort.each { |file| require_relative file }
  end
end

