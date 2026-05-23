# frozen_string_literal: true

require 'dry-validation'

module TickIt
  class SetPasswordForm < Dry::Validation::Contract
    params do
      required(:password).filled(:string)
      required(:password_confirm).filled(:string)
    end

    rule(:password_confirm) do
      key.failure('passwords do not match') unless values[:password] == values[:password_confirm]
    end
  end
end
