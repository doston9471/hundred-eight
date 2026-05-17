# frozen_string_literal: true

# After a 7, the next player(s) may stack another 7 or take from the deck.
# Two players: taking is always 2 cards (not multiplied by stacked sevens).
# Three or more: take 2 cards per seven in the current chain (`seven_chain_sevens` in payload), not
# older sevens left on the discard pile from a previous chain. If the chain root stacks a (k)th seven
# with k > player count, the next seat draws 2×k and play returns to the root in normal phase.
# Taking ends the responder's turn; play passes to the next active seat in turn order (not back to the taker).
class SevenResponseService
  Result = Struct.new(:ok, :error, keyword_init: true)

  class << self
    def take!(round:, actor_round_player:)
      round.with_lock do
        round.reload
        actor_round_player = actor_round_player.reload
        room_player = actor_round_player.room_player

        unless round.phase == "seven_response"
          return Result.new(ok: false, error: "not answering a seven")
        end
        if round.opening_seven_active?
          return Result.new(ok: false, error: "opening seven — play a normal card")
        end
        unless round.current_turn_room_player_id == room_player.id
          return Result.new(ok: false, error: "not your turn")
        end
        if round.player_out?(room_player.id)
          return Result.new(ok: false, error: "you are out of this round")
        end

        root_id = round.payload["seven_chain_root_id"] || round.payload["seven_chain_source_id"]
        return Result.new(ok: false, error: "missing seven chain") unless root_id

        return Result.new(ok: false, error: "no seven on pile") unless Game::Card.parse(round.top_discard_code).seven?

        count = penalty_draw_count(round)
        apply_seven_penalty!(round, count: count, victim_room_player_id: room_player.id, reason: "seven_take")

        round.update!(phase: "normal", required_suit: nil, payload: round.payload_without_seven_chain)
        TurnManager.advance!(round.reload, skip: 1)
        RoomBroadcaster.full_state(round.room)
        Result.new(ok: true)
      end
    end

    def play_seven!(round:, actor_round_player:, card_code:)
      round.with_lock do
        round.reload
        actor_round_player = actor_round_player.reload
        room_player = actor_round_player.room_player

        unless round.phase == "seven_response"
          return Result.new(ok: false, error: "not answering a seven")
        end
        if round.opening_seven_active?
          return Result.new(ok: false, error: "opening seven — play a normal card")
        end
        unless round.current_turn_room_player_id == room_player.id
          return Result.new(ok: false, error: "not your turn")
        end
        if round.player_out?(room_player.id)
          return Result.new(ok: false, error: "you are out of this round")
        end

        chain_root = round.payload["seven_chain_root_id"] || round.payload["seven_chain_source_id"]
        return Result.new(ok: false, error: "missing seven chain") unless chain_root

        starter_id = chain_root.to_s

        hand = actor_round_player.hand_codes
        return Result.new(ok: false, error: "card not in hand") unless hand.include?(card_code)
        return Result.new(ok: false, error: "must play a seven") unless Game::Card.parse(card_code).seven?

        top = round.top_discard_code
        return Result.new(ok: false, error: "illegal play") unless Game::Rules.legal_seven_response?(hand, card_code, top)

        new_hand = hand - [ card_code ]
        new_discard = round.discard_pile + [ card_code ]
        merged_payload = Game::SevenChain.merge_stack(round.payload, root_room_player_id: starter_id)
        actor_round_player.update!(hand: new_hand)
        round.update!(discard_pile: new_discard, payload: merged_payload)
        CardPlayRecorder.play!(round: round, round_player: actor_round_player, card_code: card_code, top_code: top)

        n = round.turn_order.size
        k = round.reload.seven_chain_sevens_count
        root_matches = (round.current_turn_room_player_id.to_s == starter_id)
        hand_empty = new_hand.empty?

        if n == 2 && hand_empty
          apply_seven_penalty!(round, count: 2 * k, victim_room_player_id: opponent_room_player_id(round, room_player.id))
          round.update!(phase: "normal", required_suit: nil, payload: round.payload_without_seven_chain)
          RoundHandEmptyService.call!(round: round.reload, room_player: room_player)
          return Result.new(ok: true)
        end

        if n >= 3 && root_matches && k >= n && (k > n || hand_empty)
          apply_seven_stack_penalty!(round, k: k)

          cleared = round.payload_without_seven_chain
          if k > n
            root_idx = round.turn_order.index(starter_id) || round.turn_order.index(chain_root)
            round.update!(phase: "normal", required_suit: nil, payload: cleared, current_turn_index: root_idx)
          else
            round.update!(phase: "normal", required_suit: nil, payload: cleared)
          end

          if hand_empty
            RoundHandEmptyService.call!(round: round.reload, room_player: room_player)
          else
            RoomBroadcaster.full_state(round.room)
          end
          return Result.new(ok: true)
        end

        if actor_round_player.reload.hand_codes.empty?
          if n >= 3 && round.turn_order.size - round.out_room_player_ids.size - 1 > 1
            RoundHandEmptyService.mark_player_out!(round.reload, room_player)
            TurnManager.advance!(round.reload, skip: 1)
            round.update!(phase: "seven_response", required_suit: nil)
            RoomBroadcaster.full_state(round.room)
          else
            RoundHandEmptyService.call!(round: round.reload, room_player: room_player)
          end
          return Result.new(ok: true)
        end

        TurnManager.advance!(round.reload, skip: 1)
        round.update!(phase: "seven_response", required_suit: nil)
        RoomBroadcaster.full_state(round.room)
        Result.new(ok: true)
      end
    end

    def apply_seven_stack_penalty!(round, k:)
      apply_seven_penalty!(round, count: 2 * k, victim_room_player_id: TurnManager.next_room_player_id(round))
    end

    def apply_seven_penalty!(round, count:, victim_room_player_id:, reason: "seven_stack")
      return if count.to_i <= 0 || victim_room_player_id.blank?

      victim_rp = round.round_players.find_by!(room_player_id: victim_room_player_id)
      DrawCardService.draw_n!(round.reload, round_player: victim_rp.reload, count: count).each do |code|
        CardPlay.create!(round: round, round_player: victim_rp, kind: :draw, card_code: code,
          metadata: { reason: reason, hidden_from_history: true })
      end
      CardPlay.create!(round: round, round_player: victim_rp, kind: :pass,
        metadata: { reason: reason, count: count })
    end

    def penalty_draw_count(round)
      2 * round.seven_chain_sevens_count
    end

    def opponent_room_player_id(round, room_player_id)
      round.turn_order.map(&:to_s).find { |id| id != room_player_id.to_s }
    end
  end
end
