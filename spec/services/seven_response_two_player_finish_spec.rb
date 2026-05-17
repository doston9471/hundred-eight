# frozen_string_literal: true

require "rails_helper"

RSpec.describe "two-player seven finish", type: :service do
  let(:room) { create(:room, :with_guest) }
  let(:rp_a) { room.room_players.find_by!(seat: 0) }
  let(:rp_b) { room.room_players.find_by!(seat: 1) }
  let(:round) do
    create(:round,
      room: room,
      number: 1,
      status: :in_progress,
      phase: "normal",
      draw_pile: %w[2|spades 3|spades 4|spades 5|spades 6|spades 7|spades 8|spades],
      discard_pile: [ "7|hearts" ],
      turn_order: [ rp_a.id, rp_b.id ],
      current_turn_index: 0,
      required_suit: nil,
      payload: {})
  end
  let!(:rpa) { create(:round_player, round: round, room_player: rp_a, hand: [ "7|clubs" ]) }
  let!(:rpb) { create(:round_player, round: round, room_player: rp_b, hand: [ "king|diamonds", "10|spades" ]) }

  it "when the winner plays their last card as a seven, the loser takes 2 then the round is scored" do
    CardPlayService.play!(round: round, actor_round_player: rpa, card_code: "7|clubs")
    expect(round.reload.status).to eq("completed")
    expect(round.winner_id).to eq(rp_a.id)
    expect(rpb.reload.hand_codes.size).to eq(4)
  end

  context "stacked sevens" do
    let(:round) do
      create(:round,
        room: room,
        number: 1,
        status: :in_progress,
        phase: "seven_response",
        draw_pile: %w[2|spades 3|spades 4|spades 5|spades 6|spades 7|spades 8|spades 9|spades],
        discard_pile: %w[7|hearts 7|diamonds],
        turn_order: [ rp_a.id, rp_b.id ],
        current_turn_index: 0,
        required_suit: nil,
        payload: { "seven_chain_root_id" => rp_b.id.to_s, "seven_chain_sevens" => 2 })
    end
    let!(:rpa) { create(:round_player, round: round, room_player: rp_a, hand: [ "7|clubs" ]) }
    let!(:rpb) { create(:round_player, round: round, room_player: rp_b, hand: [ "7|spades" ]) }

    it "when the third seven is played to go out, the loser takes 6 cards then the round ends" do
      SevenResponseService.play_seven!(round: round, actor_round_player: rpa, card_code: "7|clubs")
      expect(round.reload.status).to eq("completed")
      expect(round.winner_id).to eq(rp_a.id)
      expect(rpb.reload.hand_codes.size).to eq(7)
    end
  end

  context "take then opponent finishes on seven" do
    let(:round) do
      create(:round,
        room: room,
        number: 1,
        status: :in_progress,
        phase: "normal",
        draw_pile: %w[2|spades 3|spades 4|spades],
        discard_pile: %w[7|hearts],
        turn_order: [ rp_a.id, rp_b.id ],
        current_turn_index: 0,
        required_suit: nil,
        payload: {})
    end
    let!(:rpa) { create(:round_player, round: round, room_player: rp_a, hand: [ "7|clubs", "7|diamonds" ]) }
    let!(:rpb) { create(:round_player, round: round, room_player: rp_b, hand: [ "king|spades" ]) }

    it "after take, the root can play their last seven and the loser takes 2 again before scoring" do
      CardPlayService.play!(round: round, actor_round_player: rpa, card_code: "7|clubs")
      expect(round.reload.phase).to eq("seven_response")
      SevenResponseService.take!(round: round, actor_round_player: rpb)
      expect(rpb.reload.hand_codes.size).to eq(3)
      CardPlayService.play!(round: round, actor_round_player: rpa, card_code: "7|diamonds")
      expect(round.reload.status).to eq("completed")
      expect(rpb.reload.hand_codes.size).to eq(5)
    end
  end
end
