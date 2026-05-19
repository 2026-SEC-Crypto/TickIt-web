# frozen_string_literal: true

rspec_available = false
if ENV.fetch('RACK_ENV', 'development') != 'production'
  begin
    require 'rspec/core/rake_task'
    rspec_available = true
  rescue LoadError
    rspec_available = false
  end
end

if rspec_available
  task default: :spec

  RSpec::Core::RakeTask.new(:spec)
else
  task default: :print_env
end

desc 'Runs rubocop after specs and audit'
task style: %i[spec audit] do
  sh 'rubocop .'
end

desc 'Update vulnerabilities list and audit gems'
task :audit do
  sh 'bundle audit check --update'
end

desc 'Print environment information'
task :print_env do
  puts "Environment: #{ENV['RACK_ENV'] || 'development'}"
  puts "API_URL: #{ENV.fetch('API_URL', 'http://localhost:9292/api/v1')}"
end

desc 'Run application console (pry)'
task :console do
  require 'dotenv'
  Dotenv.load
  require_relative 'app/lib/bootstrap'
  require 'pry'
  Pry.start(TickIt)
end
