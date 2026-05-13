# frozen_string_literal: true

require 'securerandom'
require 'digest'
require_relative '../../lib/secure_db'
require_relative '../../lib/security_log'

module TickIt
  # Scheduled activity or session that students can attend
  class Event < Sequel::Model(TickIt::DB[:events])
    plugin :timestamps, update_on_create: true
    plugin :whitelist_security
    plugin :association_dependencies

    set_allowed_columns :name, :location, :start_time, :end_time, :description

    self.strict_param_setting = true
    # Many-to-Many relationship with Account
    # An event can have multiple collaborators (accounts)
    many_to_many :collaborators,
                 class: :'TickIt::Account',
                 join_table: :accounts_events,
                 left_key: :event_id,
                 right_key: :account_id

    # If an event is deleted, just remove the links in the join table, do not destroy the user accounts!
    add_association_dependencies collaborators: :nullify
    # Keep writable columns explicit to prevent mass assignment abuse.
    set_allowed_columns :name, :description, :location, :start_time, :end_time

    one_to_many :attendance_records, class: 'TickIt::AttendanceRecord'

    def before_create
      self.id ||= SecureRandom.uuid
      super
    end

    # Encryption key from config
    def self.cipher
      @cipher ||= TickIt::SecureDB.new
    end

    # Writer method - encrypt location on assignment and store hash
    def location=(value)
      TickIt::SecurityLog.log_encryption('write', self.class.name, 'location')
      self[:secure_location] = self.class.cipher.encrypt(value)
      self[:location_hash] = Digest::SHA256.hexdigest(value.to_s)
    end

    # Reader method - decrypt location on access
    def location
      TickIt::SecurityLog.log_encryption('read', self.class.name, 'secure_location')
      encrypted = self[:secure_location]
      encrypted ? self.class.cipher.decrypt(encrypted) : nil
    end

    def to_api_hash
      {
        id: id,
        name: name,
        location: location,
        start_time: start_time&.iso8601,
        end_time: end_time&.iso8601,
        description: description,
        created_at: created_at&.iso8601,
        updated_at: updated_at&.iso8601
      }
    end
  end
end
