# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  let(:user) { create(:user) }
  let(:room) { create(:room, :with_guest, host: user) }

  describe "#current_room_player" do
    it "returns the seated room player for the current user" do
      rp = room.room_players.find_by!(user: user)
      without_partial_double_verification do
        allow(helper).to receive(:current_user).and_return(user)
      end

      expect(helper.current_room_player(room)).to eq(rp)
    end

    it "returns nil when there is no current user" do
      without_partial_double_verification do
        allow(helper).to receive(:current_user).and_return(nil)
      end
      expect(helper.current_room_player(room)).to be_nil
    end
  end

  describe "#suit_glyph and #suit_glyph_class" do
    it "maps suits to glyphs and color classes" do
      expect(helper.suit_glyph("hearts")).to eq("♥")
      expect(helper.suit_glyph_class("hearts")).to eq("text-rose-400")
      expect(helper.suit_glyph("spades")).to eq("♠")
      expect(helper.suit_glyph_class("spades")).to eq("text-slate-300")
    end

    it "falls back to the suit name for unknown suits" do
      expect(helper.suit_glyph("unknown")).to eq("unknown")
      expect(helper.suit_glyph_class("unknown")).to eq("text-white")
    end
  end

  describe "#room_player_panel_frame_src" do
    let(:round) do
      create(:round,
        room: room,
        number: 1,
        status: :in_progress,
        phase: "normal",
        draw_pile: [],
        discard_pile: [ "7|hearts" ],
        turn_order: room.room_players.order(:seat).pluck(:id),
        current_turn_index: 0)
    end
    let(:host_rp) { room.room_players.find_by!(user: user) }
    let!(:round_player) { create(:round_player, round: round, room_player: host_rp, hand: [ "9|clubs" ]) }

    it "returns a player panel path with a cache-busting version" do
      src = helper.room_player_panel_frame_src(room, round)
      expect(src).to include("round_id=#{round.id}")
      expect(src).to match(/v=[a-f0-9]{20}/)
    end

    it "changes the version when a hand changes" do
      src_before = helper.room_player_panel_frame_src(room, round)
      round_player.update!(hand: [ "9|clubs", "king|hearts" ])
      src_after = helper.room_player_panel_frame_src(room, round.reload)

      expect(src_after).not_to eq(src_before)
    end

    it "returns a placeholder when there is no round" do
      expect(helper.room_player_panel_frame_src(room, nil)).to eq("#")
    end
  end
end
