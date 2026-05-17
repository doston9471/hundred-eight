# frozen_string_literal: true

module Game
  class Card
    RANKS = %w[6 7 8 9 10 jack queen king ace].freeze
    SUITS = %w[hearts diamonds clubs spades].freeze

    attr_reader :rank, :suit

    def initialize(rank, suit)
      @rank = rank.to_s
      @suit = suit.to_s
      freeze
    end

    def self.parse(code)
      rank, suit = code.to_s.split("|", 2)
      new(rank, suit)
    end

    def self.[](code)
      parse(code)
    end

    def code
      "#{rank}|#{suit}"
    end

    def six? = rank == "6"
    def seven? = rank == "7"
    def eight? = rank == "8"
    def nine? = rank == "9"
    def ten? = rank == "10"
    def jack? = rank == "jack"
    def queen? = rank == "queen"
    def king? = rank == "king"
    def ace? = rank == "ace"

    def queen_of_hearts? = queen? && suit == "hearts"

    def same_rank?(other)
      rank == other.rank
    end

    def same_suit?(other)
      suit == other.suit
    end

    def matches_discard?(top, required_suit: nil)
      return true if queen?

      legal_suit = required_suit.presence || top.suit
      same_rank?(top) || suit == legal_suit
    end

    def eql?(other)
      other.is_a?(Card) && code == other.code
    end
    alias == eql?

    def hash = code.hash
  end
end
