# frozen_string_literal: true

class JoinRoomService
  class << self
    def call!(room:, user:)
      return room if room.room_players.exists?(user_id: user.id)

      raise ArgumentError, "room is full" if room.full?
      raise ArgumentError, "game already started" unless room.waiting?

      seat = (room.room_players.maximum(:seat) || -1) + 1
      room.room_players.create!(user: user, seat: seat)
      RoomBroadcaster.full_state(room)
      room
    end
  end
end
