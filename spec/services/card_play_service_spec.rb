# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardPlayService, type: :service do
  let(:room) { create(:room, :with_guest) }
  let(:rp_a) { room.room_players.find_by!(seat: 0) }
  let(:rp_b) { room.room_players.find_by!(seat: 1) }
  let(:round) do
    create(:round,
      room: room,
      number: 1,
      status: :in_progress,
      phase: "normal",
      draw_pile: [],
      discard_pile: [ "7|hearts" ],
      turn_order: [ rp_a.id, rp_b.id ],
      current_turn_index: 0,
      required_suit: nil)
  end
  let!(:rpa) { create(:round_player, round: round, room_player: rp_a, hand: [ "7|clubs", "9|spades" ]) }
  let!(:rpb) { create(:round_player, round: round, room_player: rp_b, hand: [ "king|diamonds" ]) }

  describe ".play!" do
    it "accepts a legal play" do
      result = described_class.play!(round: round, actor_round_player: rpa, card_code: "7|clubs")
      expect(result.ok).to be true
      expect(round.reload.discard_pile.last).to eq("7|clubs")
      expect(rpa.reload.hand_codes).to eq([ "9|spades" ])
      expect(round.phase).to eq("seven_response")
      expect(round.current_turn_room_player_id).to eq(rp_b.id)
      expect(round.payload["seven_chain_root_id"]).to eq(rp_a.id.to_s)
      expect(rpb.reload.hand_codes).to eq([ "king|diamonds" ])
    end

    it "with three players, when the second player goes out the third player plays next" do
      guest2 = create(:user)
      rp_c = room.room_players.create!(user: guest2, seat: 2)
      round.update!(
        turn_order: [ rp_a.id, rp_b.id, rp_c.id ],
        discard_pile: [ "king|clubs" ],
        current_turn_index: 1)
      rpa.update!(hand: [ "9|hearts" ])
      rpb.update!(hand: [ "jack|clubs" ])
      create(:round_player, round: round, room_player: rp_c, hand: [ "10|diamonds" ])

      result = described_class.play!(round: round, actor_round_player: rpb, card_code: "jack|clubs")
      expect(result.ok).to be true
      expect(round.reload.player_out?(rp_b.id)).to be true
      expect(round.current_turn_room_player_id).to eq(rp_c.id)
    end

    it "with three players, going out on a seven enters seven_response for the next player" do
      guest2 = create(:user)
      rp_c = room.room_players.create!(user: guest2, seat: 2)
      round.update!(
        turn_order: [ rp_a.id, rp_b.id, rp_c.id ],
        discard_pile: [ "9|hearts" ],
        draw_pile: %w[2|clubs 3|clubs 4|clubs 5|clubs 6|clubs],
        current_turn_index: 0)
      rpa.update!(hand: [ "9|spades", "king|hearts" ])
      rpb.update!(hand: [ "7|spades" ])
      rpc = create(:round_player, round: round, room_player: rp_c, hand: [ "10|diamonds" ])

      described_class.play!(round: round, actor_round_player: rpa, card_code: "9|spades")
      result = described_class.play!(round: round, actor_round_player: rpb, card_code: "7|spades")

      expect(result.ok).to be true
      expect(round.reload.phase).to eq("seven_response")
      expect(round.player_out?(rp_b.id)).to be true
      expect(round.payload["seven_chain_root_id"]).to eq(rp_b.id.to_s)
      expect(round.payload["seven_chain_sevens"]).to eq(1)
      expect(round.current_turn_room_player_id).to eq(rp_c.id)

      take = SevenResponseService.take!(round: round, actor_round_player: rpc)
      expect(take.ok).to be true
      expect(rpc.reload.hand_codes.size).to eq(3)
      expect(round.reload.phase).to eq("normal")
      expect(round.current_turn_room_player_id).to eq(rp_a.id)
    end

    it "enters seven_response for the next player in a three-player game (no automatic draw)" do
      guest2 = create(:user)
      rp_c = room.room_players.create!(user: guest2, seat: 2)
      round.update!(turn_order: [ rp_a.id, rp_b.id, rp_c.id ], draw_pile: %w[2|clubs 3|clubs])
      create(:round_player, round: round, room_player: rp_c, hand: [ "ace|spades" ])
      described_class.play!(round: round, actor_round_player: rpa, card_code: "7|clubs")
      expect(round.reload.phase).to eq("seven_response")
      expect(rpb.reload.hand_codes).to eq([ "king|diamonds" ])
      expect(round.current_turn_room_player_id).to eq(rp_b.id)
      expect(round.payload["seven_chain_root_id"]).to eq(rp_a.id.to_s)
    end

    it "rejects when it is not the actor's turn" do
      result = described_class.play!(round: round, actor_round_player: rpb, card_code: "king|diamonds")
      expect(result.ok).to be false
      expect(result.error).to eq("not your turn")
    end

    it "rejects illegal plays" do
      rpa.update!(hand: [ "king|diamonds", "9|spades" ])
      result = described_class.play!(round: round, actor_round_player: rpa, card_code: "king|diamonds")
      expect(result.ok).to be false
      expect(result.error).to eq("illegal play")
    end

    it "enters ace_tail with an empty hand (draw or pass next)" do
      round.update!(discard_pile: [ "7|clubs" ])
      rpa.update!(hand: [ "ace|clubs" ])
      result = described_class.play!(round: round, actor_round_player: rpa, card_code: "ace|clubs")
      expect(result.ok).to be true
      expect(round.reload.phase).to eq("ace_tail")
      expect(rpa.reload.hand_codes).to eq([])
    end

    it "plays a six on ace_tail: previous player draws, then six rules (2p keeps turn / finish)" do
      round.update!(
        phase: "ace_tail",
        discard_pile: [ "ace|spades" ],
        draw_pile: [ "2|clubs" ],
        current_turn_index: 0
      )
      rpa.update!(hand: [ "6|spades" ])
      rpb.update!(hand: [ "king|diamonds" ])
      result = described_class.play!(round: round, actor_round_player: rpa, card_code: "6|spades")
      expect(result.ok).to be true
      expect(round.reload.phase).to eq("normal")
      expect(round.status).to eq("completed")
      expect(rpb.reload.hand_codes).to include("2|clubs")
    end

    it "rejects plays while a suit must be chosen" do
      round.update!(phase: "queen_pick_suit")
      result = described_class.play!(round: round, actor_round_player: rpa, card_code: "7|clubs")
      expect(result.error).to eq("choose suit first")
    end
  end

  describe ".choose_suit!" do
    it "sets required suit and returns to normal when still holding cards" do
      round.update!(phase: "queen_pick_suit", required_suit: nil)
      rpa.update!(hand: [ "9|hearts", "10|spades" ])
      result = described_class.choose_suit!(round: round, actor_room_player: rp_a, suit: "diamonds")
      expect(result.ok).to be true
      expect(round.reload.phase).to eq("normal")
      expect(round.required_suit).to eq("diamonds")
    end

    it "rejects when not in suit-pick phase" do
      result = described_class.choose_suit!(round: round, actor_room_player: rp_a, suit: "hearts")
      expect(result.ok).to be false
      expect(result.error).to eq("not choosing suit")
    end

    it "rejects invalid suits" do
      round.update!(phase: "queen_pick_suit")
      result = described_class.choose_suit!(round: round, actor_room_player: rp_a, suit: "invalid")
      expect(result.error).to eq("invalid suit")
    end
  end
end
