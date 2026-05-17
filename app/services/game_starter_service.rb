# frozen_string_literal: true

class GameStarterService
  class << self
    def call!(room:, host:)
      raise ArgumentError, "host only" unless room.host?(host)
      raise ArgumentError, "room not waiting" unless room.waiting?
      raise ArgumentError, "player count" unless room.player_count_in_bounds?

      ActiveRecord::Base.transaction do
        room.update!(status: :active)
        RoundStarterService.call!(room)
      end

      RoomBroadcaster.full_state(room.reload)
    end
  end
end
