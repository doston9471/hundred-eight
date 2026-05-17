# frozen_string_literal: true

require "rails_helper"

RSpec.describe Round, type: :model do
  it "validates phase inclusion" do
    room = create(:room, :with_guest)
    round = build(:round, room: room, phase: "invalid")
    expect(round).not_to be_valid
  end

  it "enforces unique number per room" do
    room = create(:room, :with_guest)
    create(:round, room: room, number: 1, turn_order: room.room_players.order(:seat).pluck(:id))
    dup = build(:round, room: room, number: 1, turn_order: room.room_players.order(:seat).pluck(:id))
    expect(dup).not_to be_valid
  end

  describe "#top_discard_code and #current_turn_room_player_id" do
    it "reads discard tail and turn order" do
      room = create(:room, :with_guest)
      ids = room.room_players.order(:seat).pluck(:id)
      round = create(:round, room: room, discard_pile: %w[6|clubs 7|hearts], turn_order: ids, current_turn_index: 0)
      expect(round.top_discard_code).to eq("7|hearts")
      expect(round.current_turn_room_player_id).to eq(ids.first)
    end
  end

  describe "#round_player_for" do
    it "finds the round_player for a room_player" do
      room = create(:room, :with_guest)
      host_rp = room.room_players.find_by(user: room.host)
      round = create(:round, room: room, turn_order: room.room_players.order(:seat).pluck(:id))
      rp = create(:round_player, round: round, room_player: host_rp, hand: %w[9|hearts])
      expect(round.round_player_for(host_rp)).to eq(rp)
    end
  end

  describe "multi-player round state" do
    let(:room) { create(:room, :with_guest) }
    let(:ids) { room.room_players.order(:seat).pluck(:id) }
    let(:round) do
      create(:round,
        room: room,
        turn_order: ids,
        payload: {
          "out_room_player_ids" => [ ids.first.to_s ],
          "round_winner_room_player_id" => ids.first.to_s
        })
    end

    it "#player_out? and #out_room_player_ids reflect payload" do
      expect(round.player_out?(ids.first)).to be true
      expect(round.player_out?(ids.second)).to be false
      expect(round.out_room_player_ids).to eq([ ids.first.to_s ])
    end

    it "#round_winner_room_player_id reads the first player out" do
      expect(round.round_winner_room_player_id).to eq(ids.first.to_s)
    end

    it "#players_still_in_round_count excludes players who are out" do
      expect(round.players_still_in_round_count).to eq(1)
    end
  end

  describe "seven chain helpers" do
    let(:room) { create(:room, :with_guest) }
    let(:round) do
      create(:round,
        room: room,
        payload: {
          "seven_chain_root_id" => "abc",
          "seven_chain_sevens" => 3,
          "other" => true
        })
    end

    it "#seven_chain_sevens_count defaults to 1 when missing" do
      round.update!(payload: {})
      expect(round.seven_chain_sevens_count).to eq(1)
    end

    it "#seven_chain_sevens_count reads the payload value" do
      expect(round.seven_chain_sevens_count).to eq(3)
    end

    it "#seven_response_penalty_draws is 2× the chain length" do
      expect(round.seven_response_penalty_draws).to eq(6)
    end

    it "#payload_without_seven_chain strips chain keys" do
      expect(round.payload_without_seven_chain).to eq("other" => true)
    end
  end

  describe "opening seven" do
    let(:room) { create(:room, :with_guest) }
    let(:ids) { room.room_players.order(:seat).pluck(:id) }
    let(:round) { create(:round, room: room, turn_order: ids, payload: { "opening_seven" => true }) }

    it "#opening_seven_active? is true when flagged in payload" do
      expect(round.opening_seven_active?).to be true
    end

    it "#opening_starter_room_player_id is the first seat in turn order" do
      expect(round.opening_starter_room_player_id).to eq(ids.first.to_s)
    end
  end

  describe "#may_pass_without_drawing?" do
    let(:room) { create(:room, :with_guest) }
    let(:round) { create(:round, room: room, draw_pile: [ "2|clubs" ], discard_pile: [ "7|hearts" ]) }

    it "is false when the deck can still yield a card and nothing was drawn this turn" do
      expect(round.may_pass_without_drawing?).to be false
    end

    it "is true after drawing on this turn" do
      round.update!(payload: { "drew_from_deck_this_turn" => true })
      expect(round.may_pass_without_drawing?).to be true
    end

    it "is true when nothing can be drawn" do
      round.update!(draw_pile: [], discard_pile: [ "7|hearts" ])
      expect(round.may_pass_without_drawing?).to be true
    end
  end
end
