# frozen_string_literal: true

class RoundStarterService
  class << self
    def call!(room)
      players = room.active_non_eliminated_players.order(:seat).to_a
      raise ArgumentError, "need at least two players" if players.size < 2

      players = rotate_loser_first(players, room.last_round_loser_room_player_id)

      deck = Game::Deck.shuffle
      n = players.size
      hands = Array.new(n) { [] }
      (5 * n).times { |i| hands[i % n] << deck.pop }

      raise "deck empty" if deck.empty?

      starter = deck.pop

      number = (room.rounds.maximum(:number) || 0) + 1
      turn_order = players.map(&:id)

      ActiveRecord::Base.transaction do
        round = room.rounds.create!(
          number: number,
          draw_pile: deck,
          discard_pile: [ starter ],
          turn_order: turn_order,
          current_turn_index: 0,
          phase: "normal",
          required_suit: nil,
          status: :in_progress
        )

        players.each_with_index do |p, idx|
          round.round_players.create!(room_player: p, hand: hands[idx])
        end

        first_rp = round.round_players.find_by!(room_player_id: round.turn_order.first)

        Game::OpeningStarter.apply!(round.reload, room: room.reload)

        round.reload
        CardPlayRecorder.round_opening!(
          round: round,
          round_player: first_rp,
          center_code: starter,
          first_turn_room_player_id: round.current_turn_room_player_id
        )

        round
      end
    end

    def rotate_loser_first(players, loser_room_player_id)
      return players unless loser_room_player_id

      idx = players.index { |p| p.id == loser_room_player_id }
      return players unless idx&.positive?

      players.rotate(idx)
    end
  end
end
