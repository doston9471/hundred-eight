# frozen_string_literal: true

module Game
  class OpeningStarter
    class << self
      def apply!(round, room:)
        round.reload
        starter = round.top_discard_code
        return unless starter

        card = Card.parse(starter)
        n = round.turn_order.size
        return if n < 2

        first_rp = round.round_players.find_by!(room_player_id: round.turn_order.first)

        if card.rank == "6"
          target_id = room.last_round_loser_room_player_id || round.turn_order.last
          target_rp = round.round_players.find_by(room_player_id: target_id)
          if target_rp
            code = DrawCardService.draw_one!(round.reload, round_player: target_rp.reload)
            if code
              CardPlay.create!(round: round, round_player: target_rp, kind: :draw, card_code: code,
                metadata: { reason: "opening_six" })
            end
          end
          round.update!(phase: "normal", current_turn_index: 0, required_suit: nil, payload: {})
        elsif card.rank == "7"
          DrawCardService.draw_n!(round.reload, round_player: first_rp.reload, count: 2).each do |code|
            CardPlay.create!(round: round, round_player: first_rp, kind: :draw, card_code: code,
              metadata: { reason: "opening_seven", hidden_from_history: true })
          end
          CardPlay.create!(round: round, round_player: first_rp, kind: :pass,
            metadata: { reason: "opening_seven", count: 2 })
          round.update!(phase: "normal", current_turn_index: 1 % n, required_suit: nil,
            payload: { "opening_seven" => true })
        elsif card.eight?
          round.update!(phase: "eight_followup", current_turn_index: 0, required_suit: nil, payload: {})
        elsif card.ace?
          round.update!(phase: "normal", current_turn_index: 1 % n, required_suit: nil, payload: {})
        elsif card.queen?
          round.update!(phase: "queen_pick_suit", current_turn_index: 0, required_suit: nil, payload: {})
        else
          round.update!(phase: "normal", current_turn_index: 0, required_suit: nil, payload: {})
        end
      end
    end
  end
end
