# frozen_string_literal: true

require "rails_helper"

RSpec.describe Game::OpeningStarter do
  let(:room) { create(:room, :with_guest) }
  let(:guest2) { create(:user) }
  let(:rp_a) { room.room_players.find_by!(seat: 0) }
  let(:rp_b) { room.room_players.find_by!(seat: 1) }
  let!(:rp_c) { room.room_players.create!(user: guest2, seat: 2) }

  it "when the opener is a seven, the first seat takes 2 cards and the next seat plays" do
    room.update!(last_round_loser_room_player_id: rp_b.id)
    turn_order = [ rp_b.id, rp_c.id, rp_a.id ]
    round = create(:round,
      room: room,
      number: 2,
      status: :in_progress,
      phase: "normal",
      draw_pile: %w[2|clubs 3|clubs 4|clubs],
      discard_pile: [ "7|hearts" ],
      turn_order: turn_order,
      current_turn_index: 0,
      payload: {})
    rpb = create(:round_player, round: round, room_player: rp_b, hand: %w[9|spades king|diamonds])
    create(:round_player, round: round, room_player: rp_c, hand: [ "8|clubs" ])
    create(:round_player, round: round, room_player: rp_a, hand: [ "10|hearts" ])

    described_class.apply!(round.reload, room: room.reload)

    expect(rpb.reload.hand_codes.size).to eq(4)
    expect(round.reload.current_turn_room_player_id).to eq(rp_c.id)
    expect(round.opening_seven_active?).to be true
  end
end
