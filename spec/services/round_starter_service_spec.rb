# frozen_string_literal: true

require "rails_helper"

RSpec.describe RoundStarterService, type: :service do
  let(:room) { create(:room, :with_guest) }

  it "deals five cards per player and exposes a starter discard" do
    round = described_class.call!(room)
    expect(round).to be_persisted
    expect(round.round_players.count).to eq(2)
    sizes = round.round_players.map { |rp| rp.hand_codes.size }
    opening_draws = round.card_plays.kind_draw.count
    expect(sizes.sum).to eq(10 + opening_draws)
    expect(sizes.min).to be >= 5
    expect(round.discard_pile.size).to eq(1)
    expect(round.draw_pile).not_to be_empty
    expect(round).to be_status_in_progress
  end

  it "raises when fewer than two players" do
    room.room_players.where.not(user_id: room.host_id).destroy_all
    expect { described_class.call!(room.reload) }.to raise_error(ArgumentError, "need at least two players")
  end
end
