# frozen_string_literal: true

require "rails_helper"

RSpec.describe RoundStarterService, "loser starts first", type: :service do
  let(:room) { create(:room, :with_guest, :active) }
  let(:guest2) { create(:user) }
  let(:rp_a) { room.room_players.find_by!(seat: 0) }
  let(:rp_b) { room.room_players.find_by!(seat: 1) }
  let!(:rp_c) { room.room_players.create!(user: guest2, seat: 2) }

  before do
    room.update!(last_round_loser_room_player_id: rp_b.id)
    create(:round, room: room, number: 1, status: :completed, turn_order: [ rp_a.id, rp_b.id, rp_c.id ],
      discard_pile: [ "9|hearts" ], draw_pile: [], winner: rp_a)
  end

  it "puts the previous round loser at the front of turn order" do
    round = described_class.call!(room.reload)
    expect(round.turn_order.first).to eq(rp_b.id)
  end
end
