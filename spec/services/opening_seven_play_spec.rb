# frozen_string_literal: true

require "rails_helper"

RSpec.describe "opening seven play flow", type: :service do
  let(:room) { create(:room, :with_guest) }
  let(:guest2) { create(:user) }
  let(:rp_a) { room.room_players.find_by!(seat: 0) }
  let(:rp_b) { room.room_players.find_by!(seat: 1) }
  let!(:rp_c) { room.room_players.create!(user: guest2, seat: 2) }
  let(:round) do
    create(:round,
      room: room,
      number: 2,
      status: :in_progress,
      phase: "normal",
      draw_pile: %w[2|clubs 3|clubs 4|clubs 5|clubs],
      discard_pile: [ "7|hearts" ],
      turn_order: [ rp_b.id, rp_c.id, rp_a.id ],
      current_turn_index: 1,
      payload: { "opening_seven" => true })
  end
  let!(:rpb) { create(:round_player, round: round, room_player: rp_b, hand: %w[9|spades king|diamonds 2|hearts 3|hearts]) }
  let!(:rpc) { create(:round_player, round: round, room_player: rp_c, hand: [ "7|clubs", "9|hearts" ]) }
  let!(:rpa) { create(:round_player, round: round, room_player: rp_a, hand: [ "10|hearts" ]) }

  it "does not enter seven_response when the second player plays a seven on the opening seven" do
    CardPlayService.play!(round: round, actor_round_player: rpc, card_code: "7|clubs")
    r = round.reload
    expect(r.phase).to eq("normal")
    expect(r.opening_seven_active?).to be false
    expect(r.current_turn_room_player_id).to eq(rp_a.id)
  end

  it "clears opening_seven when the responder plays a non-seven so the starter can play on their next turn" do
    result = CardPlayService.play!(round: round, actor_round_player: rpc, card_code: "9|hearts")
    expect(result.ok).to be true

    r = round.reload
    expect(r.phase).to eq("normal")
    expect(r.opening_seven_active?).to be false
    expect(r.current_turn_room_player_id).to eq(rp_a.id)

    play_after = CardPlayService.play!(round: r, actor_round_player: rpa, card_code: "10|hearts")
    expect(play_after.ok).to be true
    expect(play_after.error).to be_nil
  end

  it "rejects the opening starter from playing while the opening seven is unresolved" do
    round.update!(current_turn_index: 0)
    rpb.update!(hand: [ "7|spades", "9|diamonds" ])
    result7 = CardPlayService.play!(round: round.reload, actor_round_player: rpb, card_code: "7|spades")
    expect(result7.ok).to be false
    expect(result7.error).to include("opening seven")
  end
end
