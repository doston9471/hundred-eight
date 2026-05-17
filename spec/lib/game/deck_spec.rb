# frozen_string_literal: true

require "rails_helper"

RSpec.describe Game::Deck do
  describe ".full_deck_codes" do
    it "builds a 36-card deck with every rank and suit" do
      codes = described_class.full_deck_codes

      expect(codes.size).to eq(36)
      expect(codes.uniq.size).to eq(36)

      Game::Card::RANKS.each do |rank|
        Game::Card::SUITS.each do |suit|
          expect(codes).to include("#{rank}|#{suit}")
        end
      end
    end
  end

  describe ".shuffle" do
    it "returns the same cards in a different order" do
      rng = Random.new(42)
      shuffled = described_class.shuffle(rng: rng)

      expect(shuffled.sort).to eq(described_class.full_deck_codes.sort)
      expect(shuffled).not_to eq(described_class.full_deck_codes)
    end

    it "is deterministic for a fixed seed" do
      first = described_class.shuffle(rng: Random.new(7))
      second = described_class.shuffle(rng: Random.new(7))

      expect(first).to eq(second)
    end
  end
end
