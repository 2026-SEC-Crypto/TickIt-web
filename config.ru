# frozen_string_literal: true

require 'dotenv'
Dotenv.load

require_relative 'app/controllers/app'

run TickIt::Web.freeze.app
