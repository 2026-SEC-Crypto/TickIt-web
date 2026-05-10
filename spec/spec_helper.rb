# frozen_string_literal: true

require 'rspec'
require 'rack/test'
require 'json'
require 'webmock/rspec'
require_relative '../app/services/create_account'

WebMock.disable_net_connect!(allow_localhost: true)
RSpec.configure do |config|
  config.formatter = :documentation
  config.color = true
end
