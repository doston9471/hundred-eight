# frozen_string_literal: true

module CardsHelper
  SUIT_GLYPH = {
    "hearts" => "♥",
    "diamonds" => "♦",
    "clubs" => "♣",
    "spades" => "♠"
  }.freeze

  RANK_SHORT = {
    "jack" => "J",
    "queen" => "Q",
    "king" => "K",
    "ace" => "A"
  }.freeze

  def card_short_label(code)
    c = Game::Card.parse(code)
    r = RANK_SHORT.fetch(c.rank, c.rank)
    "#{r}#{SUIT_GLYPH[c.suit]}"
  end
end
