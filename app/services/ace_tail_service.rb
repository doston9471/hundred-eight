# frozen_string_literal: true

class AceTailService
  Result = Struct.new(:ok, :error, keyword_init: true)

  class << self
    def draw_one!(round:, actor_round_player:)
      round.with_lock do
        round.reload
        actor_round_player = actor_round_player.reload
        room_player = actor_round_player.room_player

        unless round.phase == "ace_tail"
          return Result.new(ok: false, error: "not in ace follow-up")
        end
        unless round.current_turn_room_player_id == room_player.id
          return Result.new(ok: false, error: "not your turn")
        end
        if round.player_out?(room_player.id)
          return Result.new(ok: false, error: "you are out of this round")
        end

        code = DrawCardService.draw_one!(round.reload, round_player: actor_round_player.reload)
        return Result.new(ok: false, error: "no cards to draw") unless code

        CardPlay.create!(round: round, round_player: actor_round_player, kind: :draw, card_code: code,
          metadata: { reason: "ace_tail_draw" })

        payload = (round.payload || {}).except("ace_tail_draw_used").merge("drew_from_deck_this_turn" => true)
        round.update!(payload: payload)
        RoomBroadcaster.full_state(round.room)
        Result.new(ok: true)
      end
    end

    def pass!(round:, actor_room_player:)
      round.with_lock do
        round.reload
        unless round.phase == "ace_tail"
          return Result.new(ok: false, error: "not in ace follow-up")
        end
        unless round.current_turn_room_player_id == actor_room_player.id
          return Result.new(ok: false, error: "not your turn")
        end
        if round.player_out?(actor_room_player.id)
          return Result.new(ok: false, error: "you are out of this round")
        end
        unless round.reload.may_pass_without_drawing?
          return Result.new(ok: false, error: "draw at least one card from the deck before passing")
        end

        skip = round.turn_order.size > 2 ? 2 : 1
        round.update!(phase: "normal", required_suit: nil, payload: {})
        TurnManager.advance!(round.reload, skip: skip)
        RoomBroadcaster.full_state(round.room)
        Result.new(ok: true)
      end
    end
  end
end
