# frozen_string_literal: true

class RoomChannel < ApplicationCable::Channel
  def subscribed
    @room = Room.find_by(id: params[:room_id])
    unless @room && current_user && @room.room_players.exists?(user_id: current_user.id)
      reject
      return
    end

    @room_player = @room.room_players.find_by!(user_id: current_user.id)
    # Satisfy Action Cable (no payloads on this stream; Turbo carries UI updates).
    stream_from "room_#{@room.id}:cable_touch"
    @room_player.mark_online!
    RoomBroadcaster.presence_strip(@room)
  end

  def unsubscribed
    @room_player&.mark_offline!
    RoomBroadcaster.presence_strip(@room) if @room
  end
end
