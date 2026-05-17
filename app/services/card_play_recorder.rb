# frozen_string_literal: true

class CardPlayRecorder
  class << self
    def play!(round:, round_player:, card_code:, top_code: nil, **metadata)
      CardPlay.create!(
        round: round,
        round_player: round_player,
        kind: :play,
        card_code: card_code,
        metadata: metadata.merge(top_code: top_code).compact
      )
    end

    def round_opening!(round:, round_player:, center_code:, first_turn_room_player_id:)
      CardPlay.create!(
        round: round,
        round_player: round_player,
        kind: :pass,
        metadata: {
          reason: "round_opening",
          center_code: center_code,
          starter_room_player_id: round_player.room_player_id.to_s,
          first_turn_room_player_id: first_turn_room_player_id.to_s
        }
      )
    end
  end
end
