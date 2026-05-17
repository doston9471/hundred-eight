# frozen_string_literal: true

require "rails_helper"

RSpec.describe RoundFinisher, type: :service do
  let(:room) { create(:room, :with_guest) }
  let(:winner_rp) { room.room_players.find_by!(user_id: room.host_id) }
  let(:loser_rp) { room.room_players.where.not(user_id: room.host_id).first! }
  let(:round) do
    create(:round,
      room: room,
      number: 1,
      status: :in_progress,
      phase: "normal",
      draw_pile: [],
      discard_pile: [ "7|hearts" ],
      turn_order: room.room_players.order(:seat).pluck(:id),
      current_turn_index: 0)
  end

  before do
    create(:round_player, round: round, room_player: winner_rp, hand: [])
    create(:round_player, round: round, room_player: loser_rp, hand: [ "jack|clubs" ])
  end

  it "scores non-winners, marks the round complete, and applies elimination rules" do
    described_class.call!(round, winner_room_player: winner_rp)
    round.reload
    expect(round).to be_status_completed
    expect(round.winner).to eq(winner_rp)
    expect(round.final_hands[loser_rp.id.to_s]).to eq([ "jack|clubs" ])
    expect(round.scoring_summary["winner_id"]).to eq(winner_rp.id.to_s)
    loser_entry = round.scoring_summary["entries"].find { |e| e["room_player_id"] == loser_rp.id.to_s }
    expect(loser_entry["hand_breakdown"].first["points"]).to eq(2)
    expect(loser_entry["points"]).to eq(2)
    expect(round.scoring_summary["loser_ids"]).to eq([ loser_rp.id.to_s ])
    expect(round.scoring_summary["round_loser_id"]).to eq(loser_rp.id.to_s)
    expect(loser_rp.reload.total_score).to eq(2)
    expect(ScoreEntry.find_by!(round: round, room_player: loser_rp).points).to eq(2)
  end

  it "is a no-op when the round is already completed" do
    described_class.call!(round, winner_room_player: winner_rp)
    expect do
      described_class.call!(round.reload, winner_room_player: winner_rp)
    end.not_to change { ScoreEntry.count }
  end
end
