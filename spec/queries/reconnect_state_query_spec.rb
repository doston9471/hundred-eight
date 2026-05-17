# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReconnectStateQuery, type: :query do
  let(:room) { create(:room, :with_guest) }
  let(:host) { room.host }
  let(:guest) { room.room_players.where.not(user_id: host.id).first!.user }

  it "returns the viewer's seat context when present" do
    round = create(:round,
      room: room,
      number: 1,
      status: :in_progress,
      phase: "normal",
      draw_pile: [],
      discard_pile: [ "7|hearts" ],
      turn_order: room.room_players.order(:seat).pluck(:id),
      current_turn_index: 0)
    host_rp = room.room_players.find_by!(user_id: host.id)
    rp_row = create(:round_player, round: round, room_player: host_rp, hand: [ "9|clubs" ])

    state = described_class.call(room: room, user: host)
    expect(state[:room]).to eq(room)
    expect(state[:room_player]).to eq(host_rp)
    expect(state[:round]).to eq(round)
    expect(state[:round_player]).to eq(rp_row)
  end

  it "returns nil associations when the user is not seated" do
    outsider = create(:user)
    state = described_class.call(room: room, user: outsider)
    expect(state[:room_player]).to be_nil
    expect(state[:round]).to be_nil
    expect(state[:round_player]).to be_nil
  end
end
