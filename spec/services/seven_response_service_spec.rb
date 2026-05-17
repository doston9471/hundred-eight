# frozen_string_literal: true

require "rails_helper"

RSpec.describe SevenResponseService, type: :service do
  let(:room) { create(:room, :with_guest) }
  let(:rp_a) { room.room_players.find_by!(seat: 0) }
  let(:rp_b) { room.room_players.find_by!(seat: 1) }
  let(:round) do
    create(:round,
      room: room,
      number: 1,
      status: :in_progress,
      phase: "seven_response",
      draw_pile: %w[2|spades 3|spades 4|spades 5|spades 6|spades 7|spades],
      discard_pile: %w[7|hearts 7|clubs],
      turn_order: [ rp_a.id, rp_b.id ],
      current_turn_index: 1,
      required_suit: nil,
      payload: { "seven_chain_root_id" => rp_a.id.to_s, "seven_chain_sevens" => 2 })
  end
  let!(:rpa) { create(:round_player, round: round, room_player: rp_a, hand: [ "9|hearts" ]) }
  let!(:rpb) { create(:round_player, round: round, room_player: rp_b, hand: [ "7|diamonds", "king|clubs" ]) }

  describe ".take!" do
    it "in two players, take draws 2 per seven in the chain (4 when two sevens are stacked)" do
      result = described_class.take!(round: round, actor_round_player: rpb)
      expect(result.ok).to be true
      expect(rpb.reload.hand_codes.size).to eq(6)
      expect(round.reload.phase).to eq("normal")
      expect(round.current_turn_room_player_id).to eq(rp_a.id)
    end

    it "in two players, take draws 6 when three sevens are in the chain" do
      round.update!(
        discard_pile: %w[7|hearts 7|clubs 7|diamonds],
        payload: { "seven_chain_root_id" => rp_a.id.to_s, "seven_chain_sevens" => 3 })
      described_class.take!(round: round, actor_round_player: rpb)
      expect(rpb.reload.hand_codes.size).to eq(8)
    end

    context "with three players" do
      let(:guest2) { create(:user) }
      let(:rp_c) { room.room_players.create!(user: guest2, seat: 2) }
      let!(:rpc) { create(:round_player, round: round, room_player: rp_c, hand: [ "9|hearts" ]) }

      before do
        round.update!(
          turn_order: [ rp_a.id, rp_b.id, rp_c.id ],
          current_turn_index: 2,
          discard_pile: %w[7|hearts 7|clubs],
          payload: { "seven_chain_root_id" => rp_a.id.to_s, "seven_chain_sevens" => 2 })
        rpb.update!(hand: [ "king|clubs" ])
      end

      it "take draws 2 per seven in the current chain (4 when two sevens are in the chain)" do
        described_class.take!(round: round, actor_round_player: rpc)
        expect(rpc.reload.hand_codes.size).to eq(5)
        expect(round.reload.current_turn_room_player_id).to eq(rp_a.id)
      end

      it "after take, turn passes to the next seat after the taker (not back to the seven chain root)" do
        round.update!(
          discard_pile: %w[king|spades 7|spades],
          payload: { "seven_chain_root_id" => rp_b.id.to_s, "seven_chain_sevens" => 1 })
        described_class.take!(round: round, actor_round_player: rpc)
        expect(round.reload.current_turn_room_player_id).to eq(rp_a.id)
        expect(round.current_turn_room_player_id).not_to eq(rp_b.id)
      end

      it "take draws 6 when three sevens are in the current chain" do
        round.update!(
          discard_pile: %w[7|hearts 7|clubs 7|diamonds],
          payload: { "seven_chain_root_id" => rp_a.id.to_s, "seven_chain_sevens" => 3 })
        described_class.take!(round: round, actor_round_player: rpc)
        expect(rpc.reload.hand_codes.size).to eq(7)
      end

      it "take draws 2 for a new chain even when older sevens remain on the discard pile" do
        round.update!(
          discard_pile: %w[7|hearts 9|clubs 7|clubs],
          payload: { "seven_chain_root_id" => rp_a.id.to_s, "seven_chain_sevens" => 1 })
        described_class.take!(round: round, actor_round_player: rpc)
        expect(rpc.reload.hand_codes.size).to eq(3)
      end
    end
  end

  describe ".play_seven!" do
    it "stacks another seven and hands turn to the opponent in seven_response" do
      result = described_class.play_seven!(round: round, actor_round_player: rpb, card_code: "7|diamonds")
      expect(result.ok).to be true
      expect(round.reload.discard_pile.last).to eq("7|diamonds")
      expect(round.phase).to eq("seven_response")
      expect(round.current_turn_room_player_id).to eq(rp_a.id)
      expect(round.payload["seven_chain_root_id"]).to eq(rp_a.id.to_s)
    end

    context "three players when the chain root stacks a fourth seven" do
      let(:guest2) { create(:user) }
      let(:rp_c) { room.room_players.create!(user: guest2, seat: 2) }
      let!(:rpc) { create(:round_player, round: round, room_player: rp_c, hand: [ "3|spades" ]) }
      let(:eight_spares) do
        %w[2|diamonds 3|diamonds 4|diamonds 5|diamonds 6|diamonds 8|diamonds 9|diamonds 10|diamonds]
      end

      before do
        round.update!(
          turn_order: [ rp_a.id, rp_b.id, rp_c.id ],
          current_turn_index: 0,
          discard_pile: %w[7|hearts 7|clubs 7|diamonds],
          payload: { "seven_chain_root_id" => rp_a.id.to_s, "seven_chain_sevens" => 3 },
          draw_pile: eight_spares)
        rpa.update!(hand: [ "7|spades" ])
        rpb.update!(hand: [ "ace|clubs" ])
      end

      it "draws 2×k onto the next seat, marks the root out, and play continues for the others" do
        result = described_class.play_seven!(round: round, actor_round_player: rpa, card_code: "7|spades")
        expect(result.ok).to be true
        expect(rpb.reload.hand_codes.size).to eq(9)
        expect(round.reload.phase).to eq("normal")
        expect(round.status).to eq("in_progress")
        expect(round.player_out?(rp_a.id)).to be true
        expect(round.round_winner_room_player_id).to eq(rp_a.id.to_s)
        expect(round.current_turn_room_player_id).to eq(rp_b.id)
        expect(round.discard_pile.last).to eq("7|spades")
      end

      it "when the root finishes on the third seven (k equals player count), the next seat takes 2×k" do
        round.update!(
          discard_pile: %w[7|hearts 7|clubs],
          payload: { "seven_chain_root_id" => rp_a.id.to_s, "seven_chain_sevens" => 2 },
          draw_pile: %w[2|diamonds 3|diamonds 4|diamonds 5|diamonds 6|diamonds 7|spades])
        rpa.update!(hand: [ "7|diamonds" ])

        result = described_class.play_seven!(round: round, actor_round_player: rpa, card_code: "7|diamonds")
        expect(result.ok).to be true
        expect(rpb.reload.hand_codes.size).to eq(7)
        expect(round.reload.player_out?(rp_a.id)).to be true
        expect(round.payload["seven_chain_sevens"]).to be_nil
      end
    end
  end
end
