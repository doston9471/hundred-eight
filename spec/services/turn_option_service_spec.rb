# frozen_string_literal: true

require "rails_helper"

RSpec.describe TurnOptionService, type: :service do
  let(:room) { create(:room, :with_guest) }
  let(:rp_a) { room.room_players.find_by!(seat: 0) }
  let(:rp_b) { room.room_players.find_by!(seat: 1) }
  let(:round) do
    create(:round,
      room: room,
      number: 1,
      status: :in_progress,
      phase: "normal",
      draw_pile: [ "2|spades" ],
      discard_pile: [ "7|hearts" ],
      turn_order: [ rp_a.id, rp_b.id ],
      current_turn_index: 0,
      required_suit: nil,
      payload: {})
  end
  let!(:rpa) { create(:round_player, round: round, room_player: rp_a, hand: [ "9|clubs" ]) }
  let!(:rpb) { create(:round_player, round: round, room_player: rp_b, hand: [ "king|diamonds" ]) }

  describe ".optional_draw_one!" do
    it "draws one card and marks the turn payload" do
      result = described_class.optional_draw_one!(round: round, actor_round_player: rpa)
      expect(result.ok).to be true
      expect(rpa.reload.hand_codes).to include("2|spades")
      expect(round.reload.payload["turn_single_draw_used"]).to be true
      expect(round.payload["drew_from_deck_this_turn"]).to be true
    end

    it "rejects a second optional draw on the same turn" do
      described_class.optional_draw_one!(round: round, actor_round_player: rpa)
      round.update!(draw_pile: [ "3|spades" ])
      result = described_class.optional_draw_one!(round: round, actor_round_player: rpa)
      expect(result.ok).to be false
    end

    it "allows unlimited draws during eight follow-up even when a closing card is already in hand" do
      round.update!(phase: "eight_followup", discard_pile: [ "8|hearts" ], draw_pile: %w[9|hearts 2|spades 3|clubs])
      rpa.update!(hand: [])

      expect(described_class.optional_draw_one!(round: round, actor_round_player: rpa).ok).to be true
      expect(rpa.reload.hand_codes).to eq([ "9|hearts" ])
      expect(round.reload.payload["turn_single_draw_used"]).to be_nil

      expect(described_class.optional_draw_one!(round: round.reload, actor_round_player: rpa.reload).ok).to be true
      expect(rpa.reload.hand_codes).to contain_exactly("9|hearts", "2|spades")

      expect(described_class.optional_draw_one!(round: round.reload, actor_round_player: rpa.reload).ok).to be true
      expect(rpa.reload.hand_codes.size).to eq(3)
    end
  end

  describe ".pass_turn!" do
    it "advances when the deck cannot yield a card (pass without drawing)" do
      round.update!(draw_pile: [], discard_pile: [ "7|hearts" ])
      result = described_class.pass_turn!(round: round, actor_room_player: rp_a)
      expect(result.ok).to be true
      expect(round.reload.current_turn_room_player_id).to eq(rp_b.id)
    end

    it "rejects pass until the player has drawn at least one card" do
      result = described_class.pass_turn!(round: round, actor_room_player: rp_a)
      expect(result.ok).to be false
    end

    it "allows pass after drawing once" do
      described_class.optional_draw_one!(round: round, actor_round_player: rpa)
      result = described_class.pass_turn!(round: round, actor_room_player: rp_a)
      expect(result.ok).to be true
    end

    it "rejects pass during eight follow-up (must close from hand)" do
      round.update!(phase: "eight_followup", discard_pile: [ "8|hearts" ], draw_pile: [ "2|spades" ])
      result = described_class.pass_turn!(round: round, actor_room_player: rp_a)
      expect(result.ok).to be false
    end
  end
end
