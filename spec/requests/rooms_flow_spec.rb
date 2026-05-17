# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rooms flow", type: :request do
  let(:host) { create(:user) }
  let(:guest) { create(:user) }

  def sign_in(user)
    post session_path, params: { email: user.email, password: "password12" }
  end

  it "shows join now on invite page when already signed in" do
    sign_in(guest)
    room = create(:room, host: host)
    raw = InviteTokenIssuer.call!(room: room)
    get room_join_path(raw)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Join now")
    expect(response.body).not_to include("Create account")
  end

  it "creates room and joins with invite" do
    sign_in(host)
    expect do
      post rooms_path, params: { room: { name: "Lobby" } }
    end.to change(Room, :count).by(1)

    room = Room.last
    expect(response).to redirect_to(room_path(room))

    raw = InviteTokenIssuer.call!(room: room)
    sign_in(guest)
    post room_join_path(raw)
    expect(response).to redirect_to(room_path(room))
    expect(room.reload.room_players.count).to eq(2)
  end

  it "shows the invite URL on the room page after the host generates one" do
    sign_in(host)
    room = create(:room, host: host)
    post create_invite_room_path(room)
    expect(response).to redirect_to(room_path(room))
    follow_redirect!
    expect(response.body).to include("http://www.example.com/join/")
    expect(response.body).to include("Invite link")
  end
end
