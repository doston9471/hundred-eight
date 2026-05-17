# frozen_string_literal: true

require "rails_helper"

RSpec.describe Game::SevenChain do
  describe ".merge_start" do
    it "starts a chain with one seven" do
      payload = described_class.merge_start({ "out_room_player_ids" => [ "x" ] }, root_room_player_id: "root")
      expect(payload["seven_chain_root_id"]).to eq("root")
      expect(payload["seven_chain_sevens"]).to eq(1)
      expect(payload["out_room_player_ids"]).to eq([ "x" ])
    end
  end

  describe ".merge_stack" do
    it "increments the chain seven count" do
      payload = described_class.merge_stack(
        { "seven_chain_root_id" => "root", "seven_chain_sevens" => 2 },
        root_room_player_id: "root"
      )
      expect(payload["seven_chain_sevens"]).to eq(3)
    end
  end
end
