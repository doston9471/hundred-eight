# frozen_string_literal: true

require "rails_helper"

RSpec.describe RoundPlayer, type: :model do
  it "enforces one round_player per room_player per round" do
    room = create(:room, :with_guest)
    round = create(:round, room: room, turn_order: room.room_players.order(:seat).pluck(:id))
    host_rp = room.room_players.find_by(user: room.host)
    create(:round_player, round: round, room_player: host_rp, hand: [])
    dup = build(:round_player, round: round, room_player: host_rp, hand: [])
    expect(dup).not_to be_valid
  end

  describe "#hand_codes" do
    it "returns hand as array of strings" do
      rp = build(:round_player, hand: %w[ace|spades])
      expect(rp.hand_codes).to eq(%w[ace|spades])
    end
  end
end
