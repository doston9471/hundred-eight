# frozen_string_literal: true

module RoomStreams
  module_function

  def stream_name(room)
    "room_#{room.id}"
  end
end
