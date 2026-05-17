# frozen_string_literal: true

class RemoveRoomPlayerService
  class << self
    def call!(room:, host:, room_player:)
      raise ArgumentError, "host only" unless room.host?(host)
      raise ArgumentError, "only before start" unless room.waiting?
      raise ArgumentError, "cannot remove host" if room_player.user_id == host.id

      room_player.destroy!
      RoomBroadcaster.full_state(room)
    end
  end
end
