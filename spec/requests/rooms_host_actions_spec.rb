# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Room host actions", type: :request do
  let(:host) { create(:user) }
  let(:guest) { create(:user) }
  let(:room) do
    create(:room, host: host).tap do |r|
      r.room_players.create!(user: guest, seat: 1)
    end
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: "password12" }
  end

  describe "POST /rooms/:id/start" do
    it "starts the game for the host" do
      sign_in(host)
      post start_room_path(room)

      expect(response).to redirect_to(room_path(room))
      expect(flash[:notice]).to eq("Game started.")
      expect(room.reload).to be_active
      expect(room.current_round).to be_present
    end

    it "rejects non-host players" do
      sign_in(guest)
      post start_room_path(room)

      expect(response).to redirect_to(room_path(room))
      expect(flash[:alert]).to eq("Only the host can do that.")
      expect(room.reload).to be_waiting
    end

    it "redirects unauthenticated users to sign in" do
      post start_room_path(room)
      expect(response).to redirect_to(new_session_path)
    end

    it "shows an alert when there are not enough players" do
      room.room_players.find_by!(user: guest).destroy!
      sign_in(host)
      post start_room_path(room)

      expect(response).to redirect_to(room_path(room))
      expect(flash[:alert]).to eq("player count")
      expect(room.reload).to be_waiting
    end
  end

  describe "POST /rooms/:id/next_round" do
    before do
      room.update!(status: :active)
      create(:round,
        room: room,
        number: 1,
        status: :completed,
        phase: "normal",
        draw_pile: [],
        discard_pile: [ "7|hearts" ],
        turn_order: room.room_players.order(:seat).pluck(:id),
        current_turn_index: 0,
        winner: room.room_players.find_by!(user: host))
    end

    it "starts the next round for the host" do
      sign_in(host)
      post next_round_room_path(room)

      expect(response).to redirect_to(room_path(room))
      expect(flash[:notice]).to eq("Next round started.")
      expect(room.reload.current_round.number).to eq(2)
      expect(room.current_round).to be_status_in_progress
    end

    it "rejects non-host players" do
      sign_in(guest)
      post next_round_room_path(room)

      expect(response).to redirect_to(room_path(room))
      expect(flash[:alert]).to eq("Only the host can do that.")
      expect(room.reload.rounds.status_in_progress.count).to eq(0)
      expect(room.rounds.maximum(:number)).to eq(1)
    end
  end

  describe "POST /rooms/:id/create_invite" do
    it "stores an invite URL in the session for the host" do
      sign_in(host)
      post create_invite_room_path(room)

      expect(response).to redirect_to(room_path(room))
      expect(flash[:notice]).to include("Invite link ready")
      expect(session["invite_url_for_room_#{room.id}"]).to be_present
      expect(room.invite_tokens.count).to eq(1)
    end

    it "rejects non-host players" do
      sign_in(guest)
      post create_invite_room_path(room)

      expect(response).to redirect_to(room_path(room))
      expect(flash[:alert]).to eq("Only the host can do that.")
      expect(room.invite_tokens.count).to eq(0)
    end
  end

  describe "POST /rooms/:id/remove_player" do
    let(:guest_rp) { room.room_players.find_by!(user: guest) }

    it "removes a guest while the room is waiting" do
      sign_in(host)
      expect {
        post remove_player_room_path(room), params: { player_id: guest_rp.id }
      }.to change { room.room_players.count }.by(-1)

      expect(response).to redirect_to(room_path(room))
      expect(flash[:notice]).to eq("Player removed.")
    end

    it "rejects removal after the game has started" do
      room.update!(status: :active)
      sign_in(host)
      post remove_player_room_path(room), params: { player_id: guest_rp.id }

      expect(response).to redirect_to(room_path(room))
      expect(flash[:alert]).to eq("only before start")
      expect(room.room_players.find_by(user: guest)).to be_present
    end

    it "rejects non-host players" do
      sign_in(guest)
      post remove_player_room_path(room), params: { player_id: guest_rp.id }

      expect(response).to redirect_to(room_path(room))
      expect(flash[:alert]).to eq("Only the host can do that.")
    end
  end
end
