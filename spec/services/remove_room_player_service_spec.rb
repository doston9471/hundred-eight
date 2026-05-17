# frozen_string_literal: true

require "rails_helper"

RSpec.describe RemoveRoomPlayerService, type: :service do
  let(:room) { create(:room, :with_guest) }
  let(:host) { room.host }
  let(:guest_rp) { room.room_players.where.not(user_id: host.id).first! }

  it "removes a non-host player while waiting" do
    expect do
      described_class.call!(room: room, host: host, room_player: guest_rp)
    end.to change { room.reload.room_players.count }.by(-1)
    expect(RoomBroadcaster).to have_received(:full_state).with(room)
  end

  it "rejects non-host callers" do
    expect do
      described_class.call!(room: room, host: guest_rp.user, room_player: guest_rp)
    end.to raise_error(ArgumentError, "host only")
  end

  it "rejects removing the host" do
    host_rp = room.room_players.find_by!(user_id: host.id)
    expect do
      described_class.call!(room: room, host: host, room_player: host_rp)
    end.to raise_error(ArgumentError, "cannot remove host")
  end

  it "rejects after the game has started" do
    room.update!(status: :active)
    expect do
      described_class.call!(room: room, host: host, room_player: guest_rp)
    end.to raise_error(ArgumentError, "only before start")
  end
end
