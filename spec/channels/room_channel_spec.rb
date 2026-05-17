# frozen_string_literal: true

require "rails_helper"

RSpec.describe RoomChannel, type: :channel do
  let(:host) { create(:user) }
  let(:guest) { create(:user) }
  let(:room) do
    create(:room, host: host).tap do |r|
      r.room_players.create!(user: guest, seat: 1)
    end
  end
  let(:host_rp) { room.room_players.find_by!(user: host) }

  describe "#subscribed" do
    it "confirms the subscription and marks the player online" do
      stub_connection(current_user: host)

      subscribe(room_id: room.id)

      expect(subscription).to be_confirmed
      expect(host_rp.reload.online).to be true
    end

    it "rejects users who are not in the room" do
      outsider = create(:user)
      stub_connection(current_user: outsider)

      subscribe(room_id: room.id)

      expect(subscription).to be_rejected
    end

    it "rejects when there is no current user" do
      stub_connection(current_user: nil)

      subscribe(room_id: room.id)

      expect(subscription).to be_rejected
    end
  end

  describe "#unsubscribed" do
    it "marks the player offline" do
      stub_connection(current_user: host)
      subscribe(room_id: room.id)
      host_rp.update!(online: true)

      unsubscribe

      expect(host_rp.reload.online).to be false
    end
  end
end
