# frozen_string_literal: true

require "rails_helper"

RSpec.describe Game::Rules do
  describe ".legal_normal_play?" do
    let(:top) { "7|hearts" }

    it "allows same rank" do
      expect(described_class.legal_normal_play?(%w[7|clubs 9|spades], "7|clubs", top, required_suit: nil, phase: "normal")).to be true
    end

    it "allows same suit" do
      expect(described_class.legal_normal_play?(%w[9|hearts], "9|hearts", top, required_suit: nil, phase: "normal")).to be true
    end

    it "allows queen on anything" do
      expect(described_class.legal_normal_play?(%w[queen|clubs], "queen|clubs", top, required_suit: nil, phase: "normal")).to be true
    end

    it "rejects illegal card" do
      expect(described_class.legal_normal_play?(%w[9|clubs], "9|clubs", top, required_suit: nil, phase: "normal")).to be false
    end

    it "respects required suit after queen" do
      expect(described_class.legal_normal_play?(%w[9|hearts 10|clubs], "9|hearts", "queen|diamonds", required_suit: "hearts", phase: "normal")).to be true
      expect(described_class.legal_normal_play?(%w[9|clubs], "9|clubs", "queen|diamonds", required_suit: "hearts", phase: "normal")).to be false
    end
  end

  describe "eight_followup phase" do
    let(:top) { "8|hearts" }

    it "allows same suit, any queen, or another eight" do
      expect(described_class.legal_normal_play?(%w[9|hearts], "9|hearts", top, required_suit: nil, phase: "eight_followup")).to be true
      expect(described_class.legal_normal_play?(%w[queen|clubs], "queen|clubs", top, required_suit: nil, phase: "eight_followup")).to be true
      expect(described_class.legal_normal_play?(%w[8|diamonds], "8|diamonds", top, required_suit: nil, phase: "eight_followup")).to be true
    end

    it "rejects wrong suit non-queen that is not another eight" do
      expect(described_class.legal_normal_play?(%w[9|clubs], "9|clubs", top, required_suit: nil, phase: "eight_followup")).to be false
    end
  end

  describe ".legal_seven_response?" do
    it "allows stacking a seven on a seven" do
      expect(described_class.legal_seven_response?(%w[7|diamonds 9|clubs], "7|diamonds", "7|hearts")).to be true
    end

    it "rejects non-sevens" do
      expect(described_class.legal_seven_response?(%w[9|clubs], "9|clubs", "7|hearts")).to be false
    end
  end

  describe ".consecutive_sevens_from_top" do
    it "counts trailing sevens on the discard pile" do
      expect(described_class.consecutive_sevens_from_top(%w[6|clubs 7|hearts 7|clubs])).to eq(2)
      expect(described_class.consecutive_sevens_from_top(%w[7|hearts 7|clubs 7|diamonds])).to eq(3)
      expect(described_class.consecutive_sevens_from_top(%w[8|hearts 7|clubs])).to eq(1)
    end
  end

  describe ".illegal_finishing_card?" do
    it "allows finishing specials to be handled in play flow" do
      expect(described_class.illegal_finishing_card?("ace|spades")).to be false
      expect(described_class.illegal_finishing_card?("8|hearts")).to be false
    end
  end

  describe "ace_tail phase" do
    let(:top) { "ace|hearts" }

    it "allows matching discard like normal" do
      expect(described_class.legal_normal_play?(%w[6|hearts], "6|hearts", top, required_suit: nil, phase: "ace_tail")).to be true
    end
  end
end
