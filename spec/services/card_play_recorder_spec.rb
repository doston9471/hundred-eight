# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardPlayRecorder, type: :service do
  let(:room) { create(:room, :with_guest) }
  let(:rp_a) { room.room_players.find_by!(seat: 0) }
  let(:rp_b) { room.room_players.find_by!(seat: 1) }
  let(:round) do
    create(:round,
      room: room,
      number: 1,
      status: :in_progress,
      phase: "normal",
      draw_pile: [],
      discard_pile: [ "7|hearts" ],
      turn_order: [ rp_a.id, rp_b.id ],
      current_turn_index: 0)
  end
  let!(:round_player) { create(:round_player, round: round, room_player: rp_a, hand: [ "9|clubs" ]) }

  describe ".play!" do
    it "records a play with card code and top discard metadata" do
      play = described_class.play!(
        round: round,
        round_player: round_player,
        card_code: "9|clubs",
        top_code: "7|hearts"
      )

      expect(play).to be_persisted
      expect(play).to be_kind_play
      expect(play.card_code).to eq("9|clubs")
      expect(play.metadata).to eq("top_code" => "7|hearts")
    end

    it "merges extra metadata" do
      play = described_class.play!(
        round: round,
        round_player: round_player,
        card_code: "9|clubs",
        top_code: "7|hearts",
        note: "test"
      )

      expect(play.metadata).to include("top_code" => "7|hearts", "note" => "test")
    end
  end

  describe ".round_opening!" do
    it "records round opening metadata for move history" do
      opening = described_class.round_opening!(
        round: round,
        round_player: round_player,
        center_code: "7|hearts",
        first_turn_room_player_id: rp_b.id
      )

      expect(opening).to be_persisted
      expect(opening).to be_kind_pass
      expect(opening.metadata).to eq(
        "reason" => "round_opening",
        "center_code" => "7|hearts",
        "starter_room_player_id" => rp_a.id.to_s,
        "first_turn_room_player_id" => rp_b.id.to_s
      )
    end
  end
end
