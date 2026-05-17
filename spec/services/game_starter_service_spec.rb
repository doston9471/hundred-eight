# frozen_string_literal: true

require "rails_helper"

RSpec.describe GameStarterService, type: :service do
  let(:room) { create(:room, :with_guest) }

  it "activates the room and starts the first round" do
    described_class.call!(room: room, host: room.host)
    room.reload
    expect(room).to be_active
    expect(room.current_round).to be_present
    expect(room.current_round.round_players.count).to eq(2)
  end

  it "rejects non-host" do
    guest = room.room_players.where.not(user_id: room.host_id).first!.user
    expect { described_class.call!(room: room, host: guest) }.to raise_error(ArgumentError, "host only")
  end

  it "rejects when not enough players" do
    room.room_players.where.not(user_id: room.host_id).destroy_all
    expect(room.reload.room_players.count).to eq(1)
    expect { described_class.call!(room: room, host: room.host) }.to raise_error(ArgumentError, "player count")
  end

  it "rejects when not waiting" do
    room.update!(status: :active)
    expect { described_class.call!(room: room, host: room.host) }.to raise_error(ArgumentError, "room not waiting")
  end
end
