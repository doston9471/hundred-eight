# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardsHelper do
  include described_class

  describe "#card_short_label" do
    it "formats face cards and number ranks with suit glyphs" do
      expect(card_short_label("jack|clubs")).to eq("J♣")
      expect(card_short_label("queen|hearts")).to eq("Q♥")
      expect(card_short_label("king|spades")).to eq("K♠")
      expect(card_short_label("ace|diamonds")).to eq("A♦")
    end

    it "keeps numeric ranks as-is" do
      expect(card_short_label("7|hearts")).to eq("7♥")
      expect(card_short_label("10|clubs")).to eq("10♣")
    end
  end
end
