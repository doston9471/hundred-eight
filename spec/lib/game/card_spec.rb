# frozen_string_literal: true

require "rails_helper"

RSpec.describe Game::Card do
  describe ".parse" do
    it "parses rank and suit from a code" do
      card = described_class.parse("jack|spades")
      expect(card.rank).to eq("jack")
      expect(card.suit).to eq("spades")
      expect(card.code).to eq("jack|spades")
    end
  end

  describe "rank predicates" do
    it "identifies special ranks" do
      expect(described_class.parse("7|hearts")).to be_seven
      expect(described_class.parse("queen|clubs")).to be_queen
      expect(described_class.parse("6|diamonds")).to be_six
    end
  end

  describe "#matches_discard?" do
    let(:top) { described_class.parse("9|hearts") }

    it "allows queens on anything" do
      queen = described_class.parse("queen|spades")
      expect(queen.matches_discard?(top)).to be true
    end

    it "allows same rank or same suit" do
      expect(described_class.parse("9|clubs").matches_discard?(top)).to be true
      expect(described_class.parse("king|hearts").matches_discard?(top)).to be true
      expect(described_class.parse("king|clubs").matches_discard?(top)).to be false
    end

    it "honors required suit after a queen" do
      expect(described_class.parse("8|diamonds").matches_discard?(top, required_suit: "diamonds")).to be true
      expect(described_class.parse("8|clubs").matches_discard?(top, required_suit: "diamonds")).to be false
    end
  end

  describe "equality" do
    it "compares by code" do
      a = described_class.parse("ace|spades")
      b = described_class.parse("ace|spades")
      expect(a).to eq(b)
      expect(a.hash).to eq(b.hash)
    end
  end
end
