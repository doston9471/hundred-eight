# frozen_string_literal: true

require "rails_helper"

RSpec.describe EliminationService, type: :service do
  let(:room) { create(:room) }

  it "eliminates over 108 and resets exactly 108" do
    rp = room.room_players.first
    rp.update!(total_score: 109)
    EliminationService.apply!(room.reload)
    expect(rp.reload.eliminated).to be true

    rp2 = create(:room_player, room: room, user: create(:user), seat: 1, total_score: 108, eliminated: false)
    EliminationService.apply!(room.reload)
    expect(rp2.reload.total_score).to eq(0)
  end
end
