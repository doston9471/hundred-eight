# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Room game actions", type: :request do
  let(:host) { create(:user) }
  let(:guest) { create(:user) }
  let(:room) do
    create(:room, :active, host: host).tap do |r|
      r.room_players.create!(user: guest, seat: 1)
    end
  end
  let(:host_rp) { room.room_players.find_by!(user: host) }
  let(:guest_rp) { room.room_players.find_by!(user: guest) }

  def sign_in(user)
    post session_path, params: { email: user.email, password: "password12" }
  end

  def create_active_round!(**attrs)
    defaults = {
      room: room,
      number: 1,
      status: :in_progress,
      phase: "normal",
      draw_pile: %w[2|clubs 3|clubs],
      discard_pile: [ "7|hearts" ],
      turn_order: [ host_rp.id, guest_rp.id ],
      current_turn_index: 0,
      required_suit: nil
    }
    create(:round, defaults.merge(attrs))
  end

  describe "authentication and membership" do
    let!(:round) { create_active_round! }

    before do
      create(:round_player, round: round, room_player: host_rp, hand: [ "9|clubs" ])
      create(:round_player, round: round, room_player: guest_rp, hand: [ "king|diamonds" ])
    end

    it "redirects unauthenticated users to sign in" do
      post play_room_path(room), params: { card_code: "9|clubs" }
      expect(response).to redirect_to(new_session_path)
    end

    it "does not let outsiders play cards" do
      outsider = create(:user)
      sign_in(outsider)
      expect {
        post play_room_path(room), params: { card_code: "9|clubs" }
      }.to throw_symbol(:abort)
      expect(round.reload.discard_pile).to eq([ "7|hearts" ])
    end
  end

  describe "POST /rooms/:id/play" do
    let!(:round) do
      create_active_round!(
        discard_pile: [ "7|hearts" ],
        current_turn_index: 0)
    end

    before do
      create(:round_player, round: round, room_player: host_rp, hand: [ "7|clubs", "9|spades" ])
      create(:round_player, round: round, room_player: guest_rp, hand: [ "king|diamonds" ])
    end

    it "plays a legal card and redirects to the room" do
      sign_in(host)
      post play_room_path(room), params: { card_code: "7|clubs" }

      expect(response).to redirect_to(room_path(room))
      expect(round.reload.phase).to eq("seven_response")
      expect(round.current_turn_room_player_id).to eq(guest_rp.id)
    end

    it "redirects with an alert when the play is illegal" do
      sign_in(host)
      post play_room_path(room), params: { card_code: "9|spades" }

      expect(response).to redirect_to(room_path(room))
      expect(flash[:alert]).to eq("illegal play")
    end

    it "redirects with an alert when it is not the player's turn" do
      sign_in(guest)
      post play_room_path(room), params: { card_code: "king|diamonds" }

      expect(response).to redirect_to(room_path(room))
      expect(flash[:alert]).to eq("not your turn")
    end
  end

  describe "POST /rooms/:id/seven_take" do
    let!(:round) do
      create_active_round!(
        phase: "seven_response",
        discard_pile: %w[7|hearts 7|clubs],
        current_turn_index: 1,
        draw_pile: %w[2|spades 3|spades 4|spades 5|spades],
        payload: { "seven_chain_root_id" => host_rp.id.to_s, "seven_chain_sevens" => 2 })
    end

    before do
      create(:round_player, round: round, room_player: host_rp, hand: [ "9|spades" ])
      create(:round_player, round: round, room_player: guest_rp, hand: [ "king|diamonds" ])
    end

    it "takes penalty cards and returns to normal play" do
      sign_in(guest)
      post seven_take_room_path(room)

      expect(response).to redirect_to(room_path(room))
      expect(round.reload.phase).to eq("normal")
      expect(guest_rp.reload.round_players.find_by(round: round).hand_codes.size).to eq(5)
    end
  end

  describe "POST /rooms/:id/suit" do
    let!(:round) do
      create_active_round!(
        phase: "queen_pick_suit",
        discard_pile: %w[7|hearts queen|clubs],
        current_turn_index: 0)
    end

    before do
      create(:round_player, round: round, room_player: host_rp, hand: [ "9|spades", "10|diamonds" ])
      create(:round_player, round: round, room_player: guest_rp, hand: [ "king|diamonds" ])
    end

    it "chooses a suit and advances the turn" do
      sign_in(host)
      post suit_room_path(room), params: { suit: "diamonds" }

      expect(response).to redirect_to(room_path(room))
      expect(round.reload.required_suit).to eq("diamonds")
      expect(round.phase).to eq("normal")
      expect(round.current_turn_room_player_id).to eq(guest_rp.id)
    end
  end

  describe "ace tail actions" do
    let!(:round) do
      create_active_round!(
        phase: "ace_tail",
        discard_pile: [ "ace|spades" ],
        draw_pile: [ "2|clubs" ],
        current_turn_index: 0)
    end

    before do
      create(:round_player, round: round, room_player: host_rp, hand: [])
      create(:round_player, round: round, room_player: guest_rp, hand: [ "king|diamonds" ])
    end

    it "draws one card during ace tail" do
      sign_in(host)
      post ace_tail_draw_room_path(room)

      expect(response).to redirect_to(room_path(room))
      expect(host_rp.reload.round_players.find_by(round: round).hand_codes).to eq([ "2|clubs" ])
    end

    it "passes after drawing during ace tail" do
      sign_in(host)
      post ace_tail_draw_room_path(room)
      post ace_pass_room_path(room)

      expect(response).to redirect_to(room_path(room))
      expect(round.reload.phase).to eq("normal")
      expect(round.current_turn_room_player_id).to eq(guest_rp.id)
    end
  end

  describe "optional draw and pass" do
    let!(:round) do
      create_active_round!(
        discard_pile: [ "9|hearts" ],
        draw_pile: [ "4|clubs" ],
        current_turn_index: 0)
    end

    before do
      create(:round_player, round: round, room_player: host_rp, hand: [ "king|spades" ])
      create(:round_player, round: round, room_player: guest_rp, hand: [ "10|diamonds" ])
    end

    it "draws optionally then passes the turn" do
      sign_in(host)
      post optional_draw_room_path(room)
      post turn_pass_room_path(room)

      expect(response).to redirect_to(room_path(room))
      expect(host_rp.reload.round_players.find_by(round: round).hand_codes).to eq([ "king|spades", "4|clubs" ])
      expect(round.reload.current_turn_room_player_id).to eq(guest_rp.id)
    end
  end

  describe "GET /rooms/:id/archive" do
    let!(:round) { create_active_round! }

    before do
      create(:round_player, round: round, room_player: host_rp, hand: [])
      create(:round_player, round: round, room_player: guest_rp, hand: [ "jack|clubs" ])
      RoundFinisher.call!(round, winner_room_player: host_rp)
    end

    it "shows completed round scoring for room members" do
      sign_in(host)
      get archive_room_path(room)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Round 1")
      expect(response.body).to include(host.username)
    end
  end
end
