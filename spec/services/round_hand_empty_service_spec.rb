# frozen_string_literal: true

require "rails_helper"

RSpec.describe RoundHandEmptyService, type: :service do
  let(:room) { create(:room, :with_guest) }
  let(:rp_a) { room.room_players.find_by!(seat: 0) }
  let(:rp_b) { room.room_players.find_by!(seat: 1) }

  describe ".call!" do
    context "with two players" do
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

      before do
        create(:round_player, round: round, room_player: rp_a, hand: [])
        create(:round_player, round: round, room_player: rp_b, hand: [ "jack|clubs" ])
      end

      it "completes the round immediately" do
        result = described_class.call!(round: round, room_player: rp_a)
        expect(result.status).to eq(:round_completed)
        expect(round.reload).to be_status_completed
        expect(round.winner_id).to eq(rp_a.id)
      end
    end

    context "with three players" do
      let(:guest2) { create(:user) }
      let(:rp_c) { room.room_players.create!(user: guest2, seat: 2) }
      let(:round) do
        create(:round,
          room: room,
          number: 1,
          status: :in_progress,
          phase: "normal",
          draw_pile: %w[2|spades],
          discard_pile: [ "7|hearts" ],
          turn_order: [ rp_a.id, rp_b.id, rp_c.id ],
          current_turn_index: 0)
      end

      before do
        create(:round_player, round: round, room_player: rp_a, hand: [])
        create(:round_player, round: round, room_player: rp_b, hand: [ "9|clubs", "10|diamonds" ])
        create(:round_player, round: round, room_player: rp_c, hand: [ "king|hearts" ])
      end

      it "marks the first player out and keeps the round in progress" do
        result = described_class.call!(round: round, room_player: rp_a)
        expect(result.status).to eq(:player_out)
        expect(round.reload).to be_status_in_progress
        expect(round.player_out?(rp_a.id)).to be true
        expect(round.round_winner_room_player_id).to eq(rp_a.id.to_s)
        expect(round.current_turn_room_player_id).to eq(rp_b.id)
      end

      it "completes the round when only one player still holds cards" do
        round.update!(
          payload: {
            "out_room_player_ids" => [ rp_a.id.to_s ],
            "round_winner_room_player_id" => rp_a.id.to_s
          },
          current_turn_index: 1)
        round.round_players.find_by!(room_player: rp_b).update!(hand: [])

        result = described_class.call!(round: round, room_player: rp_b)
        expect(result.status).to eq(:round_completed)
        expect(round.reload).to be_status_completed
        expect(round.winner_id).to eq(rp_a.id)
        expect(rp_c.reload.total_score).to eq(4)
      end
    end
  end
end
