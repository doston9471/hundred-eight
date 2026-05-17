# frozen_string_literal: true

require "rails_helper"

RSpec.describe JoinRoomService, type: :service do
  let(:room) { create(:room, :with_guest) }
  let(:new_user) { create(:user) }

  it "is idempotent when user already joined" do
    guest = room.room_players.where.not(user_id: room.host_id).first!.user
    expect(described_class.call!(room: room, user: guest)).to eq(room)
    expect(room.room_players.count).to eq(2)
  end

  it "assigns the next seat" do
    described_class.call!(room: room, user: new_user)
    expect(room.reload.room_players.order(:seat).pluck(:seat)).to contain_exactly(0, 1, 2)
  end

  it "rejects when room is full" do
    (2..4).each { |seat| room.room_players.create!(user: create(:user), seat: seat) }
    expect(room.reload.room_players.count).to eq(5)
    expect { described_class.call!(room: room, user: create(:user)) }.to raise_error(ArgumentError, "room is full")
  end

  it "rejects when game already started" do
    room.update!(status: :active)
    expect { described_class.call!(room: room, user: create(:user)) }.to raise_error(ArgumentError, "game already started")
  end
end
