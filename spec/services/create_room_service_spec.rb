# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreateRoomService, type: :service do
  it "creates a waiting room and seats the host at seat 0" do
    host = create(:user)
    room = described_class.call!(host: host, name: "  My room  ")
    expect(room).to be_persisted
    expect(room).to be_waiting
    expect(room.name).to eq("My room")
    expect(room.room_players.pluck(:user_id, :seat)).to eq([ [ host.id, 0 ] ])
  end

  it "treats whitespace-only names as absent" do
    host = create(:user)
    room = described_class.call!(host: host, name: "   ")
    expect(room.name).to be_nil
  end
end
