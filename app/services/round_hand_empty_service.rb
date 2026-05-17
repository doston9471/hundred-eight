# frozen_string_literal: true

# When a player empties their hand: in a 2-player round the round ends immediately.
# With 3+ players, they leave the round (others keep playing) until at most one player
# still holds cards; then the round ends and the first player out is the round winner.
class RoundHandEmptyService
  Result = Struct.new(:status, keyword_init: true) # :round_completed, :player_out, :already_out

  class << self
    def call!(round:, room_player:)
      round.with_lock do
        round.reload
        rp_id = room_player.id.to_s

        return Result.new(status: :already_out) if round.player_out?(rp_id)

        out_ids = round.out_room_player_ids
        still_in_after = round.turn_order.size - out_ids.size - 1

        if still_in_after <= 1
          winner = resolve_winner!(round, first_out_id: out_ids.first || rp_id)
          RoundFinisher.call!(round.reload, winner_room_player: winner)
          return Result.new(status: :round_completed)
        end

        mark_player_out!(round, room_player)
        round.update!(
          phase: "normal",
          required_suit: nil,
          payload: round.payload.except("drew_from_deck_this_turn", "turn_single_draw_used")
        )
        TurnManager.advance!(round.reload, skip: 1)
        RoomBroadcaster.full_state(round.room)
        Result.new(status: :player_out)
      end
    end

    # Marks a player as out of the round without advancing turn or changing phase.
    def mark_player_out!(round, room_player)
      rp_id = room_player.id.to_s
      return round if round.player_out?(rp_id)

      payload = (round.payload || {}).dup
      payload["out_room_player_ids"] = round.out_room_player_ids + [ rp_id ]
      payload["round_winner_room_player_id"] ||= rp_id
      round.update!(payload: payload)
      round
    end

    private

    def resolve_winner!(round, first_out_id:)
      winner_id = round.round_winner_room_player_id || first_out_id
      round.room.room_players.find(winner_id)
    end
  end
end
