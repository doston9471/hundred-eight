# frozen_string_literal: true

require "rails_helper"

RSpec.describe RoomBroadcaster, broadcast_stub: false do
  let(:room) { create(:room) }

  it "replaces the room shell and presence strip" do
    expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
      RoomStreams.stream_name(room),
      hash_including(target: "room_shell", partial: "rooms/shell", locals: { room: room })
    )
    expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
      RoomStreams.stream_name(room),
      hash_including(target: "presence_strip", partial: "rooms/presence_strip", locals: { room: room })
    )
    described_class.full_state(room)
  end

  it "replaces the presence strip" do
    expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
      RoomStreams.stream_name(room),
      hash_including(target: "presence_strip", partial: "rooms/presence_strip", locals: { room: room })
    )
    described_class.presence_strip(room)
  end

  it "appends flash messages" do
    expect(Turbo::StreamsChannel).to receive(:broadcast_append_to).with(
      RoomStreams.stream_name(room),
      hash_including(target: "room_flash", partial: "rooms/flash_message", locals: { message: "hi" })
    )
    described_class.flash(room, "hi")
  end
end
