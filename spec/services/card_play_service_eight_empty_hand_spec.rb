# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardPlayService, "eight follow-up with empty hand", type: :service do
  let(:room) { create(:room, :with_guest) }
  let(:rp_a) { room.room_players.find_by!(seat: 0) }
  let(:rp_b) { room.room_players.find_by!(seat: 1) }
  let(:round) do
    create(:round,
      room: room,
      number: 1,
      status: :in_progress,
      phase: "normal",
      draw_pile: %w[9|clubs 10|clubs jack|clubs],
      discard_pile: [ "king|clubs" ],
      turn_order: [ rp_a.id, rp_b.id ],
      current_turn_index: 0,
      required_suit: nil,
      payload: {})
  end
  let!(:rpa) { create(:round_player, round: round, room_player: rp_a, hand: [ "8|clubs" ]) }
  let!(:rpb) { create(:round_player, round: round, room_player: rp_b, hand: %w[7|hearts 9|spades king|diamonds]) }

  it "does not end the round when the only card is an 8 — player must close via eight follow-up" do
    result = described_class.play!(round: round, actor_round_player: rpa, card_code: "8|clubs")
    expect(result.ok).to be true

    r = round.reload
    expect(r.status).to eq("in_progress")
    expect(r.phase).to eq("eight_followup")
    expect(r.current_turn_room_player_id).to eq(rp_a.id)
    expect(rpa.reload.hand_codes).to be_empty

    draw = TurnOptionService.optional_draw_one!(round: r, actor_round_player: rpa)
    expect(draw.ok).to be true
    expect(rpa.reload.hand_codes).to eq([ "9|clubs" ])

    close = described_class.play!(round: r.reload, actor_round_player: rpa, card_code: "9|clubs")
    expect(close.ok).to be true
    expect(round.reload.status).to eq("completed")
    expect(round.winner_id).to eq(rp_a.id)
  end
end
