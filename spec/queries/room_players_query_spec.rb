# frozen_string_literal: true

require "rails_helper"

RSpec.describe RoomPlayersQuery, type: :query do
  it "returns players ordered by seat with users preloaded" do
    room = create(:room, :with_guest)
    rows = described_class.for_room(room)
    expect(rows.map(&:seat)).to eq([ 0, 1 ])
    expect(rows.first.association(:user)).to be_loaded
  end
end
