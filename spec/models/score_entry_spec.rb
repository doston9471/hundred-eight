# frozen_string_literal: true

require "rails_helper"

RSpec.describe ScoreEntry, type: :model do
  it "persists points and bonus" do
    room = create(:room, :with_guest)
    round = create(:round, room: room, turn_order: room.room_players.order(:seat).pluck(:id))
    host_rp = room.room_players.find_by(user: room.host)
    entry = create(:score_entry, round: round, room_player: host_rp, points: 10, bonus_points: -5)
    expect(entry.reload.points).to eq(10)
    expect(entry.bonus_points).to eq(-5)
  end
end
