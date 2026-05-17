# frozen_string_literal: true

require "rails_helper"

RSpec.describe Room, type: :model do
  describe "associations" do
    it "has a host and nested records" do
      room = create(:room)
      expect(room.host).to be_a(User)
      expect(room.room_players).to be_present
    end
  end

  describe "#host?" do
    it "is true for the host user" do
      room = create(:room)
      expect(room.host?(room.host)).to be true
      expect(room.host?(create(:user))).to be false
    end
  end

  describe "#full?" do
    it "is true when at max players" do
      room = create(:room)
      (1..4).each do |seat|
        room.room_players.create!(user: create(:user), seat: seat)
      end
      expect(room.reload).to be_full
    end
  end

  describe "#player_count_in_bounds?" do
    it "requires 2–5 players" do
      room = create(:room)
      expect(room.player_count_in_bounds?).to be false
      room.room_players.create!(user: create(:user), seat: 1)
      expect(room.reload.player_count_in_bounds?).to be true
    end
  end

  describe "#current_round" do
    it "returns the latest in-progress round" do
      room = create(:room, :with_guest, :active)
      ids = room.room_players.order(:seat).pluck(:id)
      create(:round, room: room, number: 1, status: :completed, turn_order: ids)
      active = create(:round, room: room, number: 2, status: :in_progress, turn_order: ids)
      expect(room.reload.current_round).to eq(active)
    end
  end

  describe "#between_rounds?" do
    it "is true when room is active and the latest round is completed" do
      room = create(:room, :with_guest, :active)
      ids = room.room_players.order(:seat).pluck(:id)
      create(:round, room: room, number: 1, status: :completed, turn_order: ids)
      expect(room.reload.between_rounds?).to be true
    end
  end
end
