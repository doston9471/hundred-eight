# frozen_string_literal: true

class CreateRoomService
  class << self
    def call!(host:, name: nil)
      ActiveRecord::Base.transaction do
        clean_name = name.to_s.strip.presence
        room = Room.create!(host: host, name: clean_name, status: :waiting)
        room.room_players.create!(user: host, seat: 0)
        room
      end
    end
  end
end
