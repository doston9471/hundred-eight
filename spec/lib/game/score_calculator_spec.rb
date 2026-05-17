# frozen_string_literal: true

require "rails_helper"

RSpec.describe Game::ScoreCalculator do
  it "scores ranks" do
    expect(described_class.points_for_card("9|hearts")).to eq(0)
    expect(described_class.points_for_card("jack|hearts")).to eq(2)
    expect(described_class.points_for_card("queen|hearts")).to eq(3)
    expect(described_class.points_for_card("king|hearts")).to eq(4)
    expect(described_class.points_for_card("ace|hearts")).to eq(11)
    expect(described_class.points_for_card("6|hearts")).to eq(6)
    expect(described_class.points_for_card("10|hearts")).to eq(10)
  end

  it "sums a hand" do
    codes = %w[9|hearts jack|hearts ace|hearts]
    expect(described_class.hand_total(codes)).to eq(0 + 2 + 11)
  end
end
