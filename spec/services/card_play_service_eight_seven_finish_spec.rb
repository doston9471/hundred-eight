# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardPlayService, "finishing on seven during eight follow-up (2 players)", type: :service do
  let(:room) { create(:room, :with_guest) }
  let(:rp_a) { room.room_players.find_by!(seat: 0) }
  let(:rp_b) { room.room_players.find_by!(seat: 1) }
  let(:round) do
    create(:round,
      room: room,
      number: 1,
      status: :in_progress,
      phase: "eight_followup",
      draw_pile: %w[2|spades 3|spades 4|spades 5|spades 6|spades],
      discard_pile: %w[10|clubs 8|clubs 8|hearts],
      turn_order: [ rp_a.id, rp_b.id ],
      current_turn_index: 1,
      required_suit: nil,
      payload: {})
  end
  let!(:rpa) { create(:round_player, round: round, room_player: rp_a, hand: %w[jack|clubs 7|diamonds]) }
  let!(:rpb) { create(:round_player, round: round, room_player: rp_b, hand: [ "7|hearts" ]) }

  it "makes the opponent take 2 cards before the round is scored" do
    result = described_class.play!(round: round, actor_round_player: rpb, card_code: "7|hearts")
    expect(result.ok).to be true

    r = round.reload
    expect(r.status).to eq("completed")
    expect(r.winner_id).to eq(rp_b.id)
    expect(rpa.reload.hand_codes.size).to eq(4)

    loser_entry = r.scoring_summary["entries"].find { |e| e["room_player_id"] == rp_a.id.to_s }
    expect(loser_entry["hand"].size).to eq(4)
    expect(loser_entry["points"]).to be > 0
  end
end
