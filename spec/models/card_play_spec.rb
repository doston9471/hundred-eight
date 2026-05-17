# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardPlay, type: :model do
  let(:room) { create(:room, :with_guest) }
  let(:round) { create(:round, room: room, turn_order: room.room_players.order(:seat).pluck(:id)) }
  let(:host_rp) { room.room_players.find_by!(user: room.host) }
  let(:round_player) { create(:round_player, round: round, room_player: host_rp, hand: []) }

  it "stores kind enum" do
    play = create(:card_play, round: round, round_player: round_player, kind: :draw, card_code: nil)
    expect(play).to be_kind_draw
  end

  describe ".for_history" do
    it "includes plays, passes, and suit choices but not draws" do
      play = create(:card_play, round: round, round_player: round_player, kind: :play, card_code: "9|clubs")
      pass = create(:card_play, round: round, round_player: round_player, kind: :pass,
        metadata: { reason: "six", count: 1 })
      suit = create(:card_play, round: round, round_player: round_player, kind: :suit_choice,
        metadata: { suit: "hearts" })
      draw = create(:card_play, round: round, round_player: round_player, kind: :draw, card_code: "2|clubs",
        metadata: { reason: "optional_turn", hidden_from_history: true })

      expect(described_class.for_history).to contain_exactly(play, pass, suit)
      expect(described_class.for_history).not_to include(draw)
    end
  end
end
