# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardPlayService, "eight follow-up hand chain", type: :service do
  let(:room) { create(:room, :with_guest) }
  let(:guest2) { create(:user) }
  let(:rp_a) { room.room_players.find_by!(seat: 0) }
  let(:rp_b) { room.room_players.find_by!(seat: 1) }
  let!(:rp_c) { room.room_players.create!(user: guest2, seat: 2) }
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
      payload: {})
  end
  let!(:rpa) do
    create(:round_player, round: round, room_player: rp_a,
      hand: %w[8|spades 8|hearts 8|diamonds 10|diamonds])
  end
  let!(:rpb) { create(:round_player, round: round, room_player: rp_b, hand: [ "9|clubs" ]) }
  let!(:rpc) { create(:round_player, round: round, room_player: rp_c, hand: [ "king|hearts" ]) }

  it "lets the player chain 8s and a same-suit card before the next player plays" do
    expect(described_class.play!(round: round, actor_round_player: rpa, card_code: "8|spades").ok).to be true
    expect(round.reload.phase).to eq("eight_followup")

    expect(described_class.play!(round: round, actor_round_player: rpa, card_code: "8|hearts").ok).to be true
    expect(round.reload.phase).to eq("eight_followup")

    expect(described_class.play!(round: round, actor_round_player: rpa, card_code: "8|diamonds").ok).to be true
    expect(round.reload.phase).to eq("eight_followup")

    expect(described_class.play!(round: round, actor_round_player: rpa, card_code: "10|diamonds").ok).to be true
    r = round.reload
    expect(r.phase).to eq("normal")
    expect(r.current_turn_room_player_id).to eq(rp_b.id)
    expect(r.discard_pile.last).to eq("10|diamonds")
    expect(rpa.reload.hand_codes).to be_empty
  end
end
