# frozen_string_literal: true

def require_app
  require 'roda'
  require 'figaro'
  require 'sequel'

  environment = ENV['RACK_ENV'] || 'development'
  Figaro.application = Figaro::Application.new(
    environment: environment,
    path: File.expand_path('config/secrets.yml')
  )
  Figaro.load

  require_relative 'config/environments'

  folders_to_load = ['lib', 'app/models', 'app/services', 'app/controllers/routes', 'app/controllers']

  folders_to_load.each do |folder|
    Dir.glob("#{folder}/**/*.rb").sort.each do |file|
      require_relative file
    end
  end
end
