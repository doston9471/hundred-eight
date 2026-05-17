# frozen_string_literal: true

class HostNextRoundService
  class << self
    def call!(room:, host:)
      raise ArgumentError, "host only" unless room.host?(host)
      raise ArgumentError, "room not active" unless room.active?
      raise ArgumentError, "round still playing" unless room.between_rounds?
      raise ArgumentError, "need two players" if room.active_non_eliminated_players.count < 2

      RoundStarterService.call!(room.reload)
      RoomBroadcaster.full_state(room.reload)
    end
  end
end
