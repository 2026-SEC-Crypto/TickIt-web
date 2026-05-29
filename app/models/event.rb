# frozen_string_literal: true

module TickIt
  # Represents an event returned from the API.
  class Event
    attr_reader :id, :name, :location, :start_time, :end_time,
                :attendance_start_time, :attendance_end_time, :description

    def initialize(id:, name:, location:, start_time:, end_time:,
                   attendance_start_time: nil, attendance_end_time: nil, description: nil)
      @id = id
      @name = name
      @location = location
      @start_time = start_time
      @end_time = end_time
      @attendance_start_time = attendance_start_time
      @attendance_end_time = attendance_end_time
      @description = description
    end

    def self.from_api_hash(hash)
      data = hash.transform_keys(&:to_sym)
      new(
        id: data[:id],
        name: data[:name],
        location: data[:location],
        start_time: data[:start_time],
        end_time: data[:end_time],
        attendance_start_time: data[:attendance_start_time],
        attendance_end_time: data[:attendance_end_time],
        description: data[:description]
      )
    end
  end
end
