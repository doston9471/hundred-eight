# frozen_string_literal: true

module Game
  class ScoreCalculator
    def self.points_for_card(code)
      c = Card.parse(code)
      case c.rank
      when "9" then 0
      when "jack" then 2
      when "queen" then 3
      when "king" then 4
      when "ace" then 11
      when "6" then 6
      when "7" then 7
      when "8" then 8
      when "10" then 10
      else 0
      end
    end

    def self.hand_total(codes)
      Array(codes).sum { |code| points_for_card(code) }
    end
  end
end
