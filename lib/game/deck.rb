# frozen_string_literal: true

module Game
  class Deck
    def self.full_deck_codes
      codes = []
      Card::SUITS.each do |suit|
        Card::RANKS.each do |rank|
          codes << "#{rank}|#{suit}"
        end
      end
      codes
    end

    def self.shuffle(rng: SecureRandom)
      full_deck_codes.shuffle(random: rng)
    end
  end
end
