# frozen_string_literal: true

# Turbo broadcasts are no-ops in most specs (avoid Solid Cable / stream side effects).
RSpec.configure do |config|
  config.before(:each) do |example|
    next if example.metadata[:broadcast_stub] == false

    allow(RoomBroadcaster).to receive(:full_state)
    allow(RoomBroadcaster).to receive(:presence_strip)
  end
end
