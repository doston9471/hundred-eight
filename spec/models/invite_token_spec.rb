# frozen_string_literal: true

require "rails_helper"

RSpec.describe InviteToken, type: :model do
  describe ".find_room_for_raw!" do
    it "returns the room for a valid raw token" do
      room = create(:room)
      raw = "invite-secret-#{SecureRandom.hex(8)}"
      create(:invite_token, room: room, token_digest: InviteToken.digest(raw), expires_at: 1.day.from_now)
      expect(described_class.find_room_for_raw!(raw)).to eq(room)
    end

    it "raises when token is unknown" do
      expect { described_class.find_room_for_raw!("nope") }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "raises when token is expired" do
      room = create(:room)
      raw = "expired-#{SecureRandom.hex(4)}"
      create(:invite_token, room: room, token_digest: InviteToken.digest(raw), expires_at: 1.day.ago)
      expect { described_class.find_room_for_raw!(raw) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe ".digest" do
    it "is deterministic" do
      expect(described_class.digest("a")).to eq(described_class.digest("a"))
    end
  end
end
