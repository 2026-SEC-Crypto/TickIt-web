# frozen_string_literal: true

require './require_app'
require 'fileutils'
require 'sequel'
require 'sequel/extensions/seed'

# Only require RSpec in non-production environments
begin
  require 'rspec/core/rake_task'
rescue LoadError
  # RSpec not available (e.g., production)
end

task default: :spec

desc 'Run API specs only'
task :api_spec do
  sh 'bundle exec rspec spec/api_spec.rb'
end

# desc 'Test all the specs'
# RSpec::Core::RakeTask.new(:spec) do |t|
#   t.pattern = 'spec/*_spec.rb'
# end
begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError # rubocop:disable Lint/SuppressedException
end

desc 'Runs rubocop on tested code'
task style: %i[spec audit] do
  sh 'rubocop .'
end

desc 'Update vulnerabilities list and audit gems'
task :audit do
  sh 'bundle audit check --update'
end

desc 'Checks for release'
task release_check: %i[spec style audit] do
  puts "\nReady for release!"
end

desc 'Print environment information'
task :print_env do
  puts "Environment: #{ENV['RACK_ENV'] || 'development'}"
end

desc 'Run application console (pry; Hirb enabled via .pryrc)'
task console: :print_env do
  require_relative 'require_app'
  require_app('models')
  require 'pry'
  Pry.start(TickIt)
end

namespace :db do
  desc 'Load the database connection'
  task :load do
    require_app(nil)
    require 'sequel'

    Sequel.extension :migration
    @app = TickIt::Api
  end

  desc 'Load model files'
  task :load_models do
    require_app('models')
    require_app('services')
  end

  desc 'Run migrations'
  task migrate: %i[load print_env] do
    puts 'Migrating database to latest'
    Sequel::Migrator.run(@app.DB, 'app/db/migrations')
  end

  desc 'Rollback the last migration'
  task rollback: :load do
    puts "Rolling back #{@app.environment} database..."
    latest_index = Sequel::Migrator.latest_migration_index(@app.DB, 'app/db/migrations')
    Sequel::Migrator.run(@app.DB, 'app/db/migrations', target: latest_index - 1)
    puts '✓ Rollback complete'
  end

  desc 'Reset the database (drops and recreates)'
  task reset: %i[drop migrate] do
    puts '✓ Database reset complete'
  end

  desc 'Seed the database with sample data'
  task seed: %i[migrate load_models] do
    puts "Seeding #{@app.environment} database..."

    Sequel.extension :seed
    Sequel::Seed.setup(@app.environment)
    Sequel::Seeder.apply(@app.DB, 'seeds')

    puts '✓ Database seeded'
  end

  desc 'Delete all data in database; maintain tables'
  task delete: :load_models do
    puts "Deleting all data from #{@app.environment} database..."
    @app.DB[:accounts_events].delete
    @app.DB[:attendance_records].delete
    @app.DB[:events].delete
    @app.DB[:accounts].delete
    puts '✓ All data deleted'
  end

  desc 'Delete dev or test database file'
  task drop: :load do
    if @app.environment == :production
      puts 'Cannot wipe production database!'
      return
    end

    db_filename = "db/local/#{@app.environment}.db"
    FileUtils.rm_f(db_filename)
    puts "Deleted #{db_filename}"
  end

  desc 'Show database status'
  task status: :load do
    puts "Environment: #{@app.environment}"
    puts "Database URL: #{ENV.fetch('DATABASE_URL', nil)}"

    if @app.DB.tables.empty?
      puts 'Tables: None'
    else
      puts "Tables: #{@app.DB.tables.join(', ')}"
    end
  end
  desc 'Bootstrap an admin: create-or-find EMAIL, grant admin role'
  task bootstrap_admin: %i[load load_models] do
    require 'digest'

    # 1. Read the EMAIL environment variable
    email = ENV.fetch('EMAIL', nil).to_s.strip
    abort '❌ Error: Please provide EMAIL=<email>' if email.empty?

    # 2. Find the account using the Email Hash (PII Confidentiality)
    email_hash = Digest::SHA256.hexdigest(email)
    account = TickIt::Account.first(email_hash: email_hash)

    if account.nil?
      password = ENV.fetch('PASSWORD', 'admin_password_123')
      # Model hooks handle secure_email encryption and email_hash generation
      account = TickIt::Account.create(email: email, password: password)
      puts "✅ Successfully created new secure account (id=#{account.id})"
    else
      puts 'ℹ️ Found existing account for this email hash'
    end

    # 3. Grant admin privileges (Based on lecture slides 22-23)
    # This section ensures the role exists and assigns it via system_roles
    begin
      # Ensure the 'Role' constant is defined before using it
      if Object.const_defined?('TickIt::Role')
        admin_role = TickIt::Role.first(name: 'admin') || TickIt::Role.create(name: 'admin')

        # Check for system_roles association as per lecture notes
        if account.respond_to?(:add_system_role)
          if account.system_roles_dataset.where(name: 'admin').any?
            puts '👑 Account is already an admin!'
          else
            account.add_system_role(admin_role)
            puts "👑 Successfully granted 'admin' role!"
          end
        else
          # Fallback to standard many-to-many 'add_role'
          account.add_role(admin_role) unless account.roles.include?(admin_role)
          puts "👑 Successfully granted 'admin' role via add_role!"
        end
      else
        # Fallback if no Role model exists: check for a role column on Account
        account.update(role: 'admin') if account.respond_to?(:role=)
        puts "👑 Successfully updated account role to 'admin' (Column fallback)"
      end
    rescue StandardError => e
      puts "⚠️ Warning: Could not assign role automatically: #{e.message}"
      puts 'Manual check required: Does your database have a roles table or a role column?'
    end
  end
end
