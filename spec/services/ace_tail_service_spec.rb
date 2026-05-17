# frozen_string_literal: true

require "rails_helper"

RSpec.describe AceTailService, type: :service do
  let(:room) { create(:room, :with_guest) }
  let(:rp_a) { room.room_players.find_by!(seat: 0) }
  let(:rp_b) { room.room_players.find_by!(seat: 1) }
  let(:round) do
    create(:round,
      room: room,
      number: 1,
      status: :in_progress,
      phase: "ace_tail",
      draw_pile: %w[2|clubs 3|clubs],
      discard_pile: [ "ace|spades" ],
      turn_order: [ rp_a.id, rp_b.id ],
      current_turn_index: 0,
      required_suit: nil)
  end
  let!(:rpa) { create(:round_player, round: round, room_player: rp_a, hand: []) }
  let!(:rpb) { create(:round_player, round: round, room_player: rp_b, hand: [ "king|diamonds" ]) }

  describe ".draw_one!" do
    it "draws one card and marks the turn payload" do
      result = described_class.draw_one!(round: round, actor_round_player: rpa)

      expect(result.ok).to be true
      expect(rpa.reload.hand_codes).to eq([ "2|clubs" ])
      expect(round.reload.payload["drew_from_deck_this_turn"]).to be true
      expect(round.card_plays.kind_draw.last.metadata["reason"]).to eq("ace_tail_draw")
    end

    it "rejects when not in ace_tail phase" do
      round.update!(phase: "normal")
      result = described_class.draw_one!(round: round, actor_round_player: rpa)
      expect(result.ok).to be false
      expect(result.error).to eq("not in ace follow-up")
    end

    it "rejects when it is not the actor's turn" do
      result = described_class.draw_one!(round: round, actor_round_player: rpb)
      expect(result.ok).to be false
      expect(result.error).to eq("not your turn")
    end

    it "rejects when the draw pile is empty" do
      round.update!(draw_pile: [])
      result = described_class.draw_one!(round: round, actor_round_player: rpa)
      expect(result.ok).to be false
      expect(result.error).to eq("no cards to draw")
    end
  end

  describe ".pass!" do
    it "rejects pass until the player has drawn at least one card" do
      result = described_class.pass!(round: round, actor_room_player: rp_a)
      expect(result.ok).to be false
      expect(result.error).to eq("draw at least one card from the deck before passing")
    end

    it "in two players, advances one seat and returns to normal" do
      described_class.draw_one!(round: round, actor_round_player: rpa)
      result = described_class.pass!(round: round, actor_room_player: rp_a)

      expect(result.ok).to be true
      expect(round.reload.phase).to eq("normal")
      expect(round.current_turn_room_player_id).to eq(rp_b.id)
    end

    context "with three players" do
      let(:guest2) { create(:user) }
      let(:rp_c) { room.room_players.create!(user: guest2, seat: 2) }
      let(:round) do
        create(:round,
          room: room,
          number: 1,
          status: :in_progress,
          phase: "ace_tail",
          draw_pile: [ "4|clubs" ],
          discard_pile: [ "ace|hearts" ],
          turn_order: [ rp_a.id, rp_b.id, rp_c.id ],
          current_turn_index: 0,
          required_suit: nil)
      end
      let!(:rpc) { create(:round_player, round: round, room_player: rp_c, hand: [ "10|diamonds" ]) }

      it "skips the next seat and hands turn to the following player" do
        described_class.draw_one!(round: round, actor_round_player: rpa)
        result = described_class.pass!(round: round, actor_room_player: rp_a)

        expect(result.ok).to be true
        expect(round.reload.phase).to eq("normal")
        expect(round.current_turn_room_player_id).to eq(rp_c.id)
      end
    end
  end
end
