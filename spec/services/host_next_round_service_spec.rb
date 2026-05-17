# frozen_string_literal: true

require "rails_helper"

RSpec.describe HostNextRoundService, type: :service do
  let(:room) { create(:room, :with_guest, :active) }
  let(:host) { room.host }
  let(:ids) { room.room_players.order(:seat).pluck(:id) }

  before do
    create(:round,
      room: room,
      number: 1,
      status: :completed,
      phase: "normal",
      draw_pile: [],
      discard_pile: [ "7|hearts" ],
      turn_order: ids,
      current_turn_index: 0,
      winner: room.room_players.find_by!(user_id: host.id))
  end

  it "starts a new round between completed rounds" do
    described_class.call!(room: room, host: host)
    room.reload
    expect(room.current_round).to be_present
    expect(room.current_round.number).to eq(2)
    expect(room.current_round).to be_status_in_progress
  end

  it "rejects non-host" do
    guest = room.room_players.where.not(user_id: host.id).first!.user
    expect { described_class.call!(room: room, host: guest) }.to raise_error(ArgumentError, "host only")
  end

  it "rejects when a round is still in progress" do
    room.rounds.destroy_all
    create(:round,
      room: room,
      number: 1,
      status: :in_progress,
      phase: "normal",
      draw_pile: [],
      discard_pile: [ "7|hearts" ],
      turn_order: ids,
      current_turn_index: 0)
    expect { described_class.call!(room: room, host: host) }.to raise_error(ArgumentError, "round still playing")
  end

  it "rejects when room is not active" do
    room.update!(status: :waiting)
    expect { described_class.call!(room: room, host: host) }.to raise_error(ArgumentError, "room not active")
  end

  it "raises when fewer than two active players remain" do
    room.room_players.where.not(user_id: host.id).update_all(eliminated: true)
    expect { described_class.call!(room: room, host: host) }.to raise_error(ArgumentError, "need two players")
  end
end
