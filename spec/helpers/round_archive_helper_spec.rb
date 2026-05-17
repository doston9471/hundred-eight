# frozen_string_literal: true

require "rails_helper"

RSpec.describe RoundArchiveHelper do
  include described_class

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
    RoundFinisher.call!(round, winner_room_player: winner_rp)
    round.reload
  end

  describe "#build_archive_round" do
    it "groups winner and losers from stored scoring_summary" do
      archive = build_archive_round(round)

      expect(archive.round).to eq(round)
      expect(archive.winner_entry.username).to eq(winner_rp.user.username)
      expect(archive.winner_entry.winner).to be true
      expect(archive.winner_entry.points).to eq(0)

      expect(archive.loser_entries.size).to eq(1)
      expect(archive.loser_entries.first.username).to eq(loser_rp.user.username)
      expect(archive.loser_entries.first.points).to eq(2)
      expect(archive.loser_entries.first.hand).to eq([ "jack|clubs" ])
      expect(archive.loser_entries.first.calculation).to include("jack of clubs (2)")
      expect(archive.other_entries).to be_empty
    end

    it "builds entries from score records when scoring_summary is blank" do
      round.update!(scoring_summary: {})
      archive = build_archive_round(round.reload)

      expect(archive.winner_entry.room_player_id).to eq(winner_rp.id.to_s)
      expect(archive.loser_entries.map(&:room_player_id)).to eq([ loser_rp.id.to_s ])
    end
  end
end
