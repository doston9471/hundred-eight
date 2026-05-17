# frozen_string_literal: true

require "rails_helper"

RSpec.describe TurnManager, type: :service do
  let(:room) { create(:room) }
  let(:host) { room.host }
  let(:guest) { create(:user) }
  let!(:guest_player) { room.room_players.create!(user: guest, seat: 1) }
  let(:host_player) { room.room_players.find_by!(user: host) }

  let!(:round) do
    room.rounds.create!(
      number: 1,
      status: :in_progress,
      phase: "normal",
      draw_pile: [],
      discard_pile: [ "7|hearts" ],
      turn_order: [ host_player.id, guest_player.id ],
      current_turn_index: 0,
      required_suit: nil
    )
  end

  describe ".advance!" do
    it "advances one seat by default" do
      TurnManager.advance!(round, skip: 1)
      expect(round.reload.current_turn_index).to eq(1)
    end

    it "clears turn draw flags from payload when advancing" do
      round.update!(payload: {
        "turn_single_draw_used" => true,
        "drew_from_deck_this_turn" => true,
        "opening_seven" => true
      })
      TurnManager.advance!(round, skip: 1)
      r = round.reload
      expect(r.payload["turn_single_draw_used"]).to be_nil
      expect(r.payload["drew_from_deck_this_turn"]).to be_nil
      expect(r.payload["opening_seven"]).to be true
    end
  end

  describe ".previous_room_player_id" do
    it "returns the prior seat in turn order" do
      round.update!(current_turn_index: 0)
      expect(TurnManager.previous_room_player_id(round)).to eq(guest_player.id)
    end
  end

  describe ".next_room_player_id" do
    it "returns the following seat in turn order" do
      round.update!(current_turn_index: 0)
      expect(TurnManager.next_room_player_id(round)).to eq(guest_player.id)
    end
  end
end
