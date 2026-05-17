# frozen_string_literal: true

class ReconnectStateQuery
  def self.call(room:, user:)
    {
      room: room,
      room_player: room.room_players.find_by(user: user),
      round: room.current_round,
      round_player: room.current_round && room.current_round.round_players.find_by(room_player: room.room_players.find_by(user: user))
    }
  end
end
