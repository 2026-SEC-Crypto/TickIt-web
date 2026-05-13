# frozen_string_literal: true

require 'securerandom'
module TickIt
  # Links a student to an event with check-in/out state
  class AttendanceRecord < Sequel::Model(TickIt::DB[:attendance_records])
    plugin :timestamps, update_on_create: true
    plugin :whitelist_security
    set_allowed_columns :student_number, :event_id, :check_in_time

    many_to_one :event, class: 'TickIt::Event'
    def before_create
      self.id ||= SecureRandom.uuid
      super
    end

    # Primary key lookup for API routes (invalid or non-numeric id returns nil)
    def self.with_pk_string(id_str)
      with_pk(id_str)
    end

    def api_json_hash
      {
        id: id,
        student_id: student_number, # 👈 直接讀取字串欄位，不再透過 student 關聯
        event_id: event_id,
        status: status,
        check_in_time: check_in_time,
        check_out_time: check_out_time
      }
    end
  end
end
