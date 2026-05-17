# frozen_string_literal: true

require "rails_helper"

RSpec.describe RoomPlayer, type: :model do
  it "enforces unique seat per room" do
    room = create(:room)
    create(:room_player, room: room, user: create(:user), seat: 1)
    dup = build(:room_player, room: room, user: create(:user), seat: 1)
    expect(dup).not_to be_valid
  end

  describe "#mark_online! / #mark_offline!" do
    it "toggles online and last_seen_at" do
      rp = create(:room_player, room: create(:room), user: create(:user), seat: 1, online: false)
      rp.mark_online!
      expect(rp.reload.online).to be true
      expect(rp.last_seen_at).to be_present
      rp.mark_offline!
      expect(rp.reload.online).to be false
    end
  end
end
