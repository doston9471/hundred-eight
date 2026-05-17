# frozen_string_literal: true

class RoomBroadcaster
  class << self
    def full_state(room)
      room = room.reload
      Turbo::StreamsChannel.broadcast_replace_to(
        RoomStreams.stream_name(room),
        target: "room_shell",
        partial: "rooms/shell",
        locals: { room: room }
      )
      presence_strip(room)
    end

    def flash(room, message)
      Turbo::StreamsChannel.broadcast_append_to(
        RoomStreams.stream_name(room),
        target: "room_flash",
        partial: "rooms/flash_message",
        locals: { message: message }
      )
    end

    def presence_strip(room)
      room = room.reload
      Turbo::StreamsChannel.broadcast_replace_to(
        RoomStreams.stream_name(room),
        target: "presence_strip",
        partial: "rooms/presence_strip",
        locals: { room: room }
      )
    end
  end
end
