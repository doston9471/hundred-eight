# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Room player panel", type: :request do
  let(:host) { create(:user) }

  def sign_in(user)
    post session_path, params: { email: user.email, password: "password12" }
  end

  it "shows each user only their own cards" do
    room = create(:room, :with_guest, host: host)
    host_rp = room.room_players.find_by!(user: host)
    guest_rp = room.room_players.where.not(user_id: host.id).first!
    guest_user = guest_rp.user
    round = create(:round,
      room: room,
      number: 1,
      status: :in_progress,
      phase: "normal",
      draw_pile: [],
      discard_pile: [ "7|hearts" ],
      turn_order: [ host_rp.id, guest_rp.id ],
      current_turn_index: 0,
      required_suit: nil)
    create(:round_player, round: round, room_player: host_rp, hand: [ "6|hearts", "7|clubs" ])
    create(:round_player, round: round, room_player: guest_rp, hand: [ "king|spades", "ace|diamonds" ])

    sign_in(host)
    get player_panel_room_path(room, round_id: round.id, v: "1")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("6♥")
    expect(response.body).not_to include("K♠")

    round.update!(current_turn_index: 1)
    sign_in(guest_user)
    get player_panel_room_path(room, round_id: round.id, v: "1")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("K♠")
    expect(response.body).not_to include("6♥")
  end
end
