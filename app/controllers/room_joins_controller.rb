# frozen_string_literal: true

class RoomJoinsController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    @token = params[:token]
    @room = InviteToken.find_room_for_raw!(@token)
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Invalid or expired invite."
  end

  def create
    room = InviteToken.find_room_for_raw!(params[:token])
    JoinRoomService.call!(room: room, user: current_user)
    redirect_to room_path(room)
  rescue ArgumentError => e
    redirect_to (current_user ? rooms_path : root_path), alert: e.message
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Invalid or expired invite."
  end
end
