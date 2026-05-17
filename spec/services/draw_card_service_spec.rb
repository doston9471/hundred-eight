# frozen_string_literal: true

require "rails_helper"

RSpec.describe DrawCardService, type: :service do
  let(:room) { create(:room, :with_guest) }
  let(:round) do
    create(:round,
      room: room,
      number: 1,
      status: :in_progress,
      phase: "normal",
      draw_pile: [ "9|diamonds" ],
      discard_pile: [ "7|hearts" ],
      turn_order: room.room_players.order(:seat).pluck(:id),
      current_turn_index: 0)
  end
  let(:round_player) { create(:round_player, round: round, room_player: room.room_players.first!, hand: []) }

  describe ".draw_one!" do
    it "shifts from the draw pile into the hand" do
      code = described_class.draw_one!(round, round_player: round_player)
      expect(code).to eq("9|diamonds")
      expect(round.reload.draw_pile).to be_empty
      expect(round_player.reload.hand_codes).to eq([ "9|diamonds" ])
    end

    it "returns nil when the draw pile is empty and cannot be replenished" do
      round.update!(draw_pile: [], discard_pile: [ "7|hearts" ])
      expect(described_class.draw_one!(round, round_player: round_player)).to be_nil
    end
  end

  describe ".draw_would_be_available?" do
    it "is true when the draw pile has cards" do
      expect(described_class.draw_would_be_available?(round)).to be true
    end

    it "is true when the draw pile is empty but discards can be shuffled in" do
      round.update!(draw_pile: [], discard_pile: [ "7|hearts", "8|clubs" ])
      expect(described_class.draw_would_be_available?(round)).to be true
    end

    it "is false when nothing can be drawn" do
      round.update!(draw_pile: [], discard_pile: [ "7|hearts" ])
      expect(described_class.draw_would_be_available?(round)).to be false
    end
  end

  describe ".replenish_if_empty!" do
    it "reshuffles discards except the top card into the draw pile" do
      round.update!(draw_pile: [], discard_pile: [ "7|hearts", "8|clubs", "9|diamonds" ])
      described_class.replenish_if_empty!(round)
      round.reload
      expect(round.discard_pile).to eq([ "9|diamonds" ])
      expect(round.draw_pile.sort).to eq([ "7|hearts", "8|clubs" ].sort)
    end
  end
end
