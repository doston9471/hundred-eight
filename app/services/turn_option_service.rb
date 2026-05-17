# frozen_string_literal: true

# Optional draw (once per turn) and pass for normal / eight_followup.
class TurnOptionService
  Result = Struct.new(:ok, :error, keyword_init: true)

  OPTIONAL_DRAW_PHASES = %w[normal eight_followup].freeze
  PASS_PHASES = %w[normal].freeze

  def self.log_pass!(round, actor_round_player)
    CardPlay.create!(round: round, round_player: actor_round_player, kind: :pass, metadata: { reason: "turn_pass" })
  end

  class << self
    def optional_draw_one!(round:, actor_round_player:)
      round.with_lock do
        round.reload
        actor_round_player = actor_round_player.reload
        room_player = actor_round_player.room_player

        unless OPTIONAL_DRAW_PHASES.include?(round.phase)
          return Result.new(ok: false, error: "cannot draw here")
        end
        unless round.current_turn_room_player_id == room_player.id
          return Result.new(ok: false, error: "not your turn")
        end
        if round.player_out?(room_player.id)
          return Result.new(ok: false, error: "you are out of this round")
        end
        if round.phase == "eight_followup"
          top = round.top_discard_code
          legal = top && Game::Rules.any_legal_play?(
            actor_round_player.hand_codes, top, required_suit: nil, phase: "eight_followup"
          )
          if legal && round.payload["turn_single_draw_used"]
            return Result.new(ok: false, error: "already drew one card this turn")
          end
        elsif round.payload["turn_single_draw_used"]
          return Result.new(ok: false, error: "already drew one card this turn")
        end

        code = DrawCardService.draw_one!(round.reload, round_player: actor_round_player.reload)
        return Result.new(ok: false, error: "no cards to draw") unless code

        CardPlay.create!(round: round, round_player: actor_round_player, kind: :draw, card_code: code,
          metadata: { reason: "optional_turn" })

        p = (round.payload || {}).merge("turn_single_draw_used" => true, "drew_from_deck_this_turn" => true)
        round.update!(payload: p)
        RoomBroadcaster.full_state(round.room)
        Result.new(ok: true)
      end
    end

    def pass_turn!(round:, actor_room_player:)
      round.with_lock do
        round.reload
        unless PASS_PHASES.include?(round.phase)
          return Result.new(ok: false, error: "cannot pass in this phase")
        end
        unless round.current_turn_room_player_id == actor_room_player.id
          return Result.new(ok: false, error: "not your turn")
        end
        if round.player_out?(actor_room_player.id)
          return Result.new(ok: false, error: "you are out of this round")
        end
        if round.phase != "eight_followup" && !round.reload.may_pass_without_drawing?
          return Result.new(ok: false, error: "draw at least one card from the deck before passing")
        end

        rp = round.round_player_for(actor_room_player)
        log_pass!(round, rp) if rp

        if round.phase == "eight_followup"
          round.reload.update!(phase: "normal", required_suit: nil)
        end
        TurnManager.advance!(round.reload, skip: 1)
        RoomBroadcaster.full_state(round.room)
        Result.new(ok: true)
      end
    end
  end
end
