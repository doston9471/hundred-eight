# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardPlayService, "three-player six and ace turns", type: :service do
  let(:room) { create(:room, :with_guest) }
  let(:rp_a) { room.room_players.find_by!(seat: 0) }
  let(:rp_b) { room.room_players.find_by!(seat: 1) }
  let(:guest2) { create(:user) }
  let(:rp_c) { room.room_players.create!(user: guest2, seat: 2) }
  let(:round) do
    create(:round,
      room: room,
      number: 1,
      status: :in_progress,
      phase: "normal",
      draw_pile: %w[2|clubs 3|clubs 4|clubs],
      discard_pile: [ "9|hearts" ],
      turn_order: [ rp_a.id, rp_b.id, rp_c.id ],
      current_turn_index: 2,
      required_suit: nil)
  end
  let!(:rpa) { create(:round_player, round: round, room_player: rp_a, hand: [ "king|spades" ]) }
  let!(:rpb) { create(:round_player, round: round, room_player: rp_b, hand: [ "queen|diamonds" ]) }
  let!(:rpc) { create(:round_player, round: round, room_player: rp_c, hand: [ "6|hearts", "8|spades" ]) }

  it "after a six from seat 3, seat 2 draws and seat 1 plays" do
    described_class.play!(round: round, actor_round_player: rpc, card_code: "6|hearts")
    expect(rpb.reload.hand_codes.size).to eq(2)
    expect(round.reload.current_turn_room_player_id).to eq(rp_a.id)
  end

  it "after an ace from seat 3, seat 1 is skipped and seat 2 plays" do
    rpc.update!(hand: [ "ace|hearts", "8|spades" ])
    described_class.play!(round: round, actor_round_player: rpc, card_code: "ace|hearts")
    expect(round.reload.current_turn_room_player_id).to eq(rp_b.id)
  end

  it "after an ace from seat 2, seat 3 is skipped and seat 1 plays" do
    round.update!(current_turn_index: 1, discard_pile: [ "9|diamonds" ])
    rpb.update!(hand: [ "ace|diamonds", "8|clubs" ])
    described_class.play!(round: round, actor_round_player: rpb, card_code: "ace|diamonds")
    expect(round.reload.current_turn_room_player_id).to eq(rp_a.id)
  end
end
