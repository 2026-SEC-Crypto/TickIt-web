# frozen_string_literal: true

require 'rspec'
require 'rack/test'
require 'json'
require 'webmock/rspec'

ENV['MSG_KEY'] ||= 'XIgPh/65Phv0wvz0Q7ui5rN3irs3+aIUnrotBb7KSno='
ENV['SESSION_KEY'] ||= 'dev-tickit-secure-key-minimum-64-characters-required-for-production-use-now'
ENV['API_URL'] ||= 'http://api.test.local/api/v1'

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.formatter = :documentation
  config.color = true
end
