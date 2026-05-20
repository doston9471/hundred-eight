# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardPlayService, "two-player six chain", type: :service do
  let(:room) { create(:room, :with_guest) }
  let(:rp_a) { room.room_players.find_by!(seat: 0) }
  let(:rp_b) { room.room_players.find_by!(seat: 1) }
  let(:round) do
    create(:round,
      room: room,
      number: 1,
      status: :in_progress,
      phase: "normal",
      draw_pile: %w[2|spades 3|spades 4|spades],
      discard_pile: [ "6|clubs" ],
      turn_order: [ rp_a.id, rp_b.id ],
      current_turn_index: 1,
      required_suit: nil,
      payload: { "drew_from_deck_this_turn" => true, "turn_single_draw_used" => true })
  end
  let!(:rpa) { create(:round_player, round: round, room_player: rp_a, hand: [ "jack|spades" ]) }
  let!(:rpb) do
    create(:round_player, round: round, room_player: rp_b, hand: [ "6|spades", "6|hearts", "9|spades" ])
  end

  it "keeps the six player's turn and blocks pass until they draw again after chaining sixes" do
    expect(described_class.play!(round: round, actor_round_player: rpb, card_code: "6|spades").ok).to be true
    expect(rpa.reload.hand_codes.size).to eq(2)
    r = round.reload
    expect(r.current_turn_room_player_id).to eq(rp_b.id)
    expect(r.six_followup_continue?).to be true
    expect(r.payload["drew_from_deck_this_turn"]).to be_nil
    expect(r.may_pass_without_drawing?).to be false

    expect(described_class.play!(round: round.reload, actor_round_player: rpb.reload, card_code: "6|hearts").ok).to be true
    expect(rpa.reload.hand_codes.size).to eq(3)
    r = round.reload
    expect(r.current_turn_room_player_id).to eq(rp_b.id)
    expect(r.may_pass_without_drawing?).to be false

    pass = TurnOptionService.pass_turn!(round: r, actor_room_player: rp_b)
    expect(pass.ok).to be false
    expect(pass.error).to include("draw")

    draw = TurnOptionService.optional_draw_one!(round: r, actor_round_player: rpb.reload)
    expect(draw.ok).to be true
    expect(r.reload.may_pass_without_drawing?).to be true

    pass_after = TurnOptionService.pass_turn!(round: r.reload, actor_room_player: rp_b)
    expect(pass_after.ok).to be true
    expect(r.reload.current_turn_room_player_id).to eq(rp_a.id)
    expect(r.payload["six_followup_continue"]).to be_nil
  end

  it "ends the six follow-up when the player plays a matching non-six card" do
    described_class.play!(round: round, actor_round_player: rpb, card_code: "6|spades")
    result = described_class.play!(round: round.reload, actor_round_player: rpb.reload, card_code: "9|spades")
    expect(result.ok).to be true
    r = round.reload
    expect(r.current_turn_room_player_id).to eq(rp_a.id)
    expect(r.payload["six_followup_continue"]).to be_nil
  end
end
