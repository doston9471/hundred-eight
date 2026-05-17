# frozen_string_literal: true

require "rails_helper"

RSpec.describe MoveHistoryHelper, type: :helper do
  let(:room) { create(:room, :with_guest) }
  let(:guest) { room.room_players.where.not(user_id: room.host_id).first! }
  let(:host_rp) { room.room_players.find_by!(user_id: room.host_id) }

  describe "#round_start_header" do
    let(:round) do
      create(:round,
        room: room,
        turn_order: [ guest.id, host_rp.id ],
        current_turn_index: 1,
        discard_pile: [ "7|hearts" ])
    end
    let!(:guest_round_player) { create(:round_player, round: round, room_player: guest, hand: []) }
    let!(:host_round_player) { create(:round_player, round: round, room_player: host_rp, hand: []) }

    it "shows who starts and the center card" do
      create(:card_play, round: round, round_player: guest_round_player, kind: :pass,
        metadata: {
          reason: "round_opening",
          center_code: "7|hearts",
          starter_room_player_id: guest.id.to_s,
          first_turn_room_player_id: host_rp.id.to_s
        })

      expect(helper.round_start_header(round)).to eq(
        "#{guest.user.username} starts — center: 7♥. #{host_rp.user.username} plays first"
      )
    end

    it "falls back to round data when no opening entry exists" do
      expect(helper.round_start_header(round)).to include("#{guest.user.username} starts")
      expect(helper.round_start_header(round)).to include("7♥")
    end
  end

  describe "#card_play_description" do
    let(:round) { create(:round, room: room, turn_order: [ host_rp.id ], discard_pile: [ "king|clubs" ]) }
    let(:round_player) { create(:round_player, round: round, room_player: host_rp, hand: []) }

    it "describes a play with short card labels" do
      play = create(:card_play, round: round, round_player: round_player, kind: :play,
        card_code: "10|clubs", metadata: { top_code: "king|clubs" })
      expect(helper.card_play_description(play)).to eq(
        "#{host_rp.user.username} played 10♣ on K♣"
      )
    end

    it "describes a six penalty as taking one card" do
      play = create(:card_play, round: round, round_player: round_player, kind: :pass,
        metadata: { reason: "six", count: 1 })
      expect(helper.card_play_description(play)).to eq(
        "#{host_rp.user.username} took 1 card"
      )
    end

    it "describes a queen suit choice" do
      play = create(:card_play, round: round, round_player: round_player, kind: :suit_choice,
        metadata: { suit: "diamonds" })
      expect(helper.card_play_description(play)).to eq(
        "#{host_rp.user.username} chose ♦ (diamonds)"
      )
    end

    it "describes a seven take" do
      play = create(:card_play, round: round, round_player: round_player, kind: :pass,
        metadata: { reason: "seven_take", count: 4 })
      expect(helper.card_play_description(play)).to eq(
        "#{host_rp.user.username} took 4 cards"
      )
    end

    it "describes a generic pass" do
      play = create(:card_play, round: round, round_player: round_player, kind: :pass, metadata: {})
      expect(helper.card_play_description(play)).to eq("#{host_rp.user.username} passed")
    end
  end

  describe "#round_history_plays" do
    let(:round) { create(:round, room: room, turn_order: room.room_players.pluck(:id)) }
    let(:round_player) { create(:round_player, round: round, room_player: host_rp, hand: []) }

    it "excludes the round opening entry from the play list" do
      create(:card_play, round: round, round_player: round_player, kind: :pass,
        metadata: { reason: "round_opening", center_code: "7|hearts" })
      play = create(:card_play, round: round, round_player: round_player, kind: :play,
        card_code: "9|clubs", metadata: { top_code: "7|hearts" })

      expect(helper.round_history_plays(round, chronological: true).map(&:id)).to eq([ play.id ])
    end

    it "returns newest plays first by default" do
      older = create(:card_play, round: round, round_player: round_player, kind: :play,
        card_code: "9|clubs", metadata: { top_code: "7|hearts" }, created_at: 2.minutes.ago)
      newer = create(:card_play, round: round, round_player: round_player, kind: :play,
        card_code: "10|clubs", metadata: { top_code: "9|clubs" }, created_at: 1.minute.ago)

      expect(helper.round_history_plays(round).map(&:id)).to eq([ newer.id, older.id ])
    end
  end
end
