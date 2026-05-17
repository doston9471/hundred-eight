# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardPlayService, "six when a player is out", type: :service do
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
      draw_pile: %w[2|clubs 3|clubs],
      discard_pile: [ "jack|spades" ],
      turn_order: [ rp_a.id, rp_b.id, rp_c.id ],
      current_turn_index: 0,
      required_suit: nil,
      payload: { "out_room_player_ids" => [ rp_b.id.to_s ], "round_winner_room_player_id" => rp_b.id.to_s })
  end
  let!(:rpa) { create(:round_player, round: round, room_player: rp_a, hand: [ "6|spades", "9|diamonds" ]) }
  let!(:rpb) { create(:round_player, round: round, room_player: rp_b, hand: []) }
  let!(:rpc) { create(:round_player, round: round, room_player: rp_c, hand: [ "king|hearts" ]) }

  it "penalizes the previous active player but leaves the turn with the player who played the six" do
    expect do
      described_class.play!(round: round, actor_round_player: rpa, card_code: "6|spades")
    end.to change { rpc.reload.hand_codes.size }.by(1)

    expect(round.reload.current_turn_room_player_id).to eq(rp_a.id)
    expect(rpa.reload.hand_codes).to eq([ "9|diamonds" ])
  end
end
