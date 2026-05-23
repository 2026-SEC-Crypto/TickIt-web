# frozen_string_literal: true

require 'dry-validation'

module TickIt
  class RegisterForm < Dry::Validation::Contract
    params do
      required(:username).filled(:string)
      required(:email).filled(:string)
    end

    rule(:email) do
      key.failure('must be a valid email address') unless value.include?('@')
    end
  end
end
