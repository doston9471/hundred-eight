# frozen_string_literal: true

require "rails_helper"

RSpec.describe "separate seven chains in three players", type: :service do
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
      draw_pile: %w[2|spades 3|spades 4|spades 5|spades 6|spades 8|spades],
      discard_pile: [ "9|hearts" ],
      turn_order: [ rp_a.id, rp_b.id, rp_c.id ],
      current_turn_index: 0,
      required_suit: nil)
  end
  let!(:rpa) { create(:round_player, round: round, room_player: rp_a, hand: [ "7|hearts", "7|clubs", "king|diamonds" ]) }
  let!(:rpb) { create(:round_player, round: round, room_player: rp_b, hand: [ "queen|spades", "10|clubs" ]) }
  let!(:rpc) { create(:round_player, round: round, room_player: rp_c, hand: [ "jack|diamonds" ]) }

  it "charges two cards per new chain even when old sevens remain on the discard pile" do
    CardPlayService.play!(round: round, actor_round_player: rpa, card_code: "7|hearts")
    expect(round.reload.phase).to eq("seven_response")
    expect(round.payload["seven_chain_sevens"]).to eq(1)

    SevenResponseService.take!(round: round, actor_round_player: rpb)
    expect(rpb.reload.hand_codes.size).to eq(4)
    expect(round.reload.phase).to eq("normal")
    expect(round.current_turn_room_player_id).to eq(rp_c.id)

    TurnOptionService.optional_draw_one!(round: round, actor_round_player: rpc)
    TurnOptionService.pass_turn!(round: round, actor_room_player: rp_c)
    expect(round.reload.current_turn_room_player_id).to eq(rp_a.id)

    CardPlayService.play!(round: round, actor_round_player: rpa, card_code: "7|clubs")
    expect(round.reload.phase).to eq("seven_response")
    expect(round.payload["seven_chain_sevens"]).to eq(1)

    SevenResponseService.take!(round: round, actor_round_player: rpb)
    expect(rpb.reload.hand_codes.size).to eq(6)
  end
end
