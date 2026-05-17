# frozen_string_literal: true

class RoomPlayersQuery
  def self.for_room(room)
    room.room_players.includes(:user).order(:seat)
  end
end
