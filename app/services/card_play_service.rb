# frozen_string_literal: true

class CardPlayService
  Result = Struct.new(:ok, :error, keyword_init: true)

  class << self
    def choose_suit!(round:, actor_room_player:, suit:)
      round.with_lock do
        round.reload
        unless round.phase == "queen_pick_suit"
          return Result.new(ok: false, error: "not choosing suit")
        end
        unless round.current_turn_room_player_id == actor_room_player.id
          return Result.new(ok: false, error: "not your turn")
        end
        if round.player_out?(actor_room_player.id)
          return Result.new(ok: false, error: "you are out of this round")
        end
        unless Game::Card::SUITS.include?(suit.to_s)
          return Result.new(ok: false, error: "invalid suit")
        end

        round.update!(required_suit: suit, phase: "normal")
        rp = round.round_player_for(actor_room_player)
        CardPlay.create!(round: round, round_player: rp, kind: :suit_choice, metadata: { suit: suit })

        if rp.reload.hand_codes.empty?
          RoundHandEmptyService.call!(round: round.reload, room_player: actor_room_player)
        else
          TurnManager.advance!(round.reload, skip: 1)
          RoomBroadcaster.full_state(round.room)
        end

        Result.new(ok: true)
      end
    end

    def play!(round:, actor_round_player:, card_code:)
      round.with_lock do
        round.reload
        actor_round_player = actor_round_player.reload
        room_player = actor_round_player.room_player

        if round.phase == "ace_tail"
          return play_ace_tail!(round: round, actor_round_player: actor_round_player, card_code: card_code)
        end

        unless round.current_turn_room_player_id == room_player.id
          return Result.new(ok: false, error: "not your turn")
        end
        if round.player_out?(room_player.id)
          return Result.new(ok: false, error: "you are out of this round")
        end
        if round.opening_seven_active? && room_player.id.to_s == round.opening_starter_room_player_id
          return Result.new(ok: false, error: "you already took two cards for the opening seven — wait for your next turn")
        end
        if round.phase == "queen_pick_suit"
          return Result.new(ok: false, error: "choose suit first")
        end
        if round.phase == "seven_response"
          return SevenResponseService.play_seven!(round: round, actor_round_player: actor_round_player, card_code: card_code)
        end
        if round.phase == "eight_followup"
          return play_in_eight_followup!(round: round, actor_round_player: actor_round_player, card_code: card_code)
        end

        top = round.top_discard_code
        return Result.new(ok: false, error: "no discard") unless top

        hand = actor_round_player.hand_codes
        return Result.new(ok: false, error: "card not in hand") unless hand.include?(card_code)

        card = Game::Card.parse(card_code)

        unless Game::Rules.legal_normal_play?(hand, card_code, top, required_suit: round.required_suit, phase: round.phase)
          return Result.new(ok: false, error: "illegal play")
        end

        new_hand = hand - [ card_code ]
        actor_round_player.update!(hand: new_hand)
        pl = (round.payload || {}).except("turn_single_draw_used")
        round.update!(discard_pile: round.discard_pile + [ card_code ], payload: pl)
        CardPlayRecorder.play!(round: round, round_player: actor_round_player, card_code: card_code, top_code: top)

        if card.six?
          apply_six_penalty!(round, actor_round_player)
          actor_round_player.reload
          if actor_round_player.hand_codes.empty?
            broadcast_unless_finished!(round, actor_round_player)
            return Result.new(ok: true)
          end
          finalize_six_turn!(round, room_player.id)
          broadcast_unless_finished!(round, actor_round_player)
          return Result.new(ok: true)
        end

        if card.seven?
          if round.opening_seven_active?
            if room_player.id.to_s == round.opening_starter_room_player_id
              return Result.new(ok: false, error: "you already took two cards for the opening seven")
            end
            pl = (round.payload || {}).except("opening_seven", "turn_single_draw_used", "drew_from_deck_this_turn")
            round.update!(payload: pl)
            if new_hand.empty?
              RoundHandEmptyService.call!(round: round.reload, room_player: room_player)
              return Result.new(ok: true)
            end
            finalize_standard_card!(round, card)
            broadcast_unless_finished!(round, actor_round_player)
            return Result.new(ok: true)
          end

          if new_hand.empty?
            if round.turn_order.size == 2
              opponent_id = SevenResponseService.opponent_room_player_id(round, room_player.id)
              SevenResponseService.apply_seven_penalty!(round, count: 2, victim_room_player_id: opponent_id, reason: "seven_take")
              RoundHandEmptyService.call!(round: round.reload, room_player: room_player)
              return Result.new(ok: true)
            end

            still_in_after = round.turn_order.size - round.out_room_player_ids.size - 1
            if still_in_after <= 1
              RoundHandEmptyService.call!(round: round.reload, room_player: room_player)
              return Result.new(ok: true)
            end

            rid = room_player.id.to_s
            TurnManager.advance!(round.reload, skip: 1)
            RoundHandEmptyService.mark_player_out!(round.reload, room_player)
            pl7 = Game::SevenChain.merge_start(
              round.payload.except("turn_single_draw_used", "drew_from_deck_this_turn"),
              root_room_player_id: rid
            )
            round.update!(phase: "seven_response", required_suit: nil, payload: pl7)
            RoomBroadcaster.full_state(round.room)
            return Result.new(ok: true)
          end

          rid = room_player.id.to_s
          TurnManager.advance!(round.reload, skip: 1)
          pl7 = (round.payload || {}).except("turn_single_draw_used", "drew_from_deck_this_turn")
          round.update!(
            phase: "seven_response",
            required_suit: nil,
            payload: Game::SevenChain.merge_start(pl7, root_room_player_id: rid)
          )
          broadcast_unless_finished!(round, actor_round_player)
          return Result.new(ok: true)
        end

        if card.eight?
          pl8 = (round.reload.payload || {}).except("turn_single_draw_used", "drew_from_deck_this_turn")
          round.update!(phase: "eight_followup", required_suit: nil, payload: pl8)
          broadcast_unless_finished!(round, actor_round_player)
          return Result.new(ok: true)
        end

        if card.queen?
          round.update!(phase: "queen_pick_suit", required_suit: nil)
          broadcast_unless_finished!(round, actor_round_player)
          return Result.new(ok: true)
        end

        if card.ace? && new_hand.empty?
          round.update!(phase: "ace_tail", required_suit: nil, payload: {})
          broadcast_unless_finished!(round, actor_round_player)
          return Result.new(ok: true)
        end

        if new_hand.empty?
          RoundHandEmptyService.call!(round: round.reload, room_player: room_player)
          return Result.new(ok: true)
        end

        finalize_standard_card!(round, card)
        RoomBroadcaster.full_state(round.room)
        Result.new(ok: true)
      end
    end

    private

    def play_in_eight_followup!(round:, actor_round_player:, card_code:)
      room_player = actor_round_player.room_player
      top = round.top_discard_code
      return Result.new(ok: false, error: "no discard") unless top

      hand = actor_round_player.hand_codes
      return Result.new(ok: false, error: "card not in hand") unless hand.include?(card_code)

      unless Game::Rules.legal_normal_play?(hand, card_code, top, required_suit: nil, phase: "eight_followup")
        return Result.new(ok: false, error: "illegal play")
      end

      card = Game::Card.parse(card_code)
      new_hand = hand - [ card_code ]
      actor_round_player.update!(hand: new_hand)
      pl = (round.payload || {}).except("turn_single_draw_used")
      round.update!(discard_pile: round.discard_pile + [ card_code ], payload: pl)
      CardPlayRecorder.play!(round: round, round_player: actor_round_player, card_code: card_code, top_code: top)

      if card.six?
        apply_six_penalty!(round, actor_round_player)
        actor_round_player.reload
        if actor_round_player.hand_codes.empty?
          broadcast_unless_finished!(round, actor_round_player)
          return Result.new(ok: true)
        end
        end_eight_followup!(round)
        finalize_six_turn!(round, room_player.id)
        broadcast_unless_finished!(round, actor_round_player)
        return Result.new(ok: true)
      end

      if card.seven?
        if new_hand.empty?
          end_eight_followup!(round)
          RoundHandEmptyService.call!(round: round.reload, room_player: room_player)
          return Result.new(ok: true)
        end

        rid = room_player.id.to_s
        end_eight_followup!(round)
        TurnManager.advance!(round.reload, skip: 1)
        pl7 = (round.payload || {}).except("turn_single_draw_used", "drew_from_deck_this_turn")
        round.update!(
          phase: "seven_response",
          required_suit: nil,
          payload: Game::SevenChain.merge_start(pl7, root_room_player_id: rid)
        )
        broadcast_unless_finished!(round, actor_round_player)
        return Result.new(ok: true)
      end

      if card.eight?
        round.update!(phase: "eight_followup", required_suit: nil)
        broadcast_unless_finished!(round, actor_round_player)
        return Result.new(ok: true)
      end

      if card.queen?
        end_eight_followup!(round)
        round.update!(phase: "queen_pick_suit", required_suit: nil)
        broadcast_unless_finished!(round, actor_round_player)
        return Result.new(ok: true)
      end

      if card.ace? && new_hand.empty?
        end_eight_followup!(round)
        round.update!(phase: "ace_tail", required_suit: nil, payload: {})
        broadcast_unless_finished!(round, actor_round_player)
        return Result.new(ok: true)
      end

      end_eight_followup!(round)
      if new_hand.empty?
        RoundHandEmptyService.call!(round: round.reload, room_player: room_player)
        return Result.new(ok: true)
      end

      finalize_standard_card!(round, card)
      broadcast_unless_finished!(round, actor_round_player)
      Result.new(ok: true)
    end

    def end_eight_followup!(round)
      round.update!(phase: "normal", required_suit: nil) if round.phase == "eight_followup"
    end

    def play_ace_tail!(round:, actor_round_player:, card_code:)
      room_player = actor_round_player.room_player
      unless round.current_turn_room_player_id == room_player.id
        return Result.new(ok: false, error: "not your turn")
      end

      top = round.top_discard_code
      return Result.new(ok: false, error: "no discard") unless top

      hand = actor_round_player.hand_codes
      return Result.new(ok: false, error: "card not in hand") unless hand.include?(card_code)

      unless Game::Rules.legal_normal_play?(hand, card_code, top, required_suit: round.required_suit, phase: "ace_tail")
        return Result.new(ok: false, error: "illegal play")
      end

      card = Game::Card.parse(card_code)
      new_hand = hand - [ card_code ]
      actor_round_player.update!(hand: new_hand)
      pl = (round.payload || {}).except("turn_single_draw_used")
      round.update!(discard_pile: round.discard_pile + [ card_code ], payload: pl)
      CardPlayRecorder.play!(round: round, round_player: actor_round_player, card_code: card_code, top_code: top)

      if card.ace? && new_hand.empty?
        round.update!(phase: "ace_tail", required_suit: nil, payload: {})
        broadcast_unless_finished!(round, actor_round_player)
        return Result.new(ok: true)
      end

      round.update!(phase: "normal", required_suit: nil, payload: {})
      actor_round_player.reload

      if card.six?
        apply_six_penalty!(round, actor_round_player)
        actor_round_player.reload
        if actor_round_player.hand_codes.empty?
          broadcast_unless_finished!(round, actor_round_player)
          return Result.new(ok: true)
        end
        finalize_six_turn!(round, room_player.id)
        broadcast_unless_finished!(round, actor_round_player)
        return Result.new(ok: true)
      end

      if actor_round_player.hand_codes.empty?
        RoundHandEmptyService.call!(round: round.reload, room_player: room_player)
        return Result.new(ok: true)
      end

      finalize_standard_card!(round, card)
      RoomBroadcaster.full_state(round.room)
      Result.new(ok: true)
    end

    def broadcast_unless_finished!(round, actor_round_player)
      return if try_finish_round!(round, actor_round_player)

      RoomBroadcaster.full_state(round.room)
    end

    def apply_six_penalty!(round, actor_round_player)
      prev_id = TurnManager.previous_room_player_id(round)
      return unless prev_id

      prev_rp = round.round_players.find_by!(room_player_id: prev_id)
      code = DrawCardService.draw_one!(round.reload, round_player: prev_rp)
      return unless code

      CardPlay.create!(round: round, round_player: prev_rp, kind: :draw, card_code: code,
        metadata: { reason: "six", hidden_from_history: true })
      CardPlay.create!(round: round, round_player: prev_rp, kind: :pass,
        metadata: { reason: "six", count: 1 })
    end

    def finalize_six_turn!(round, actor_room_player_id)
      round.reload
      aid = actor_room_player_id.to_s
      idx = round.turn_order.index(aid) || round.turn_order.index(actor_room_player_id)
      # With only two players still in the round, the six player keeps the turn (after the penalty draw).
      # With three or more, play passes to the next active seat after the six player (penalty victim does not play).
      if round.turn_order.size == 2 || round.players_still_in_round_count <= 2
        round.update!(phase: "normal", required_suit: nil, current_turn_index: idx)
      else
        round.update!(phase: "normal", required_suit: nil)
        TurnManager.advance!(round, skip: 1)
      end
    end

    def finalize_standard_card!(round, card)
      round.reload
      round.update!(phase: "normal", required_suit: nil)
      skip = card.ace? ? 2 : 1
      TurnManager.advance!(round.reload, skip: skip)
    end

    def try_finish_round!(round, actor_round_player)
      actor_round_player.reload
      return false unless actor_round_player.hand_codes.empty?

      result = RoundHandEmptyService.call!(round: round.reload, room_player: actor_round_player.room_player)
      result.status != :already_out
    end
  end
end
