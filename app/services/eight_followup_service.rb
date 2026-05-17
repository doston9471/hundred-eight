# frozen_string_literal: true

# After playing an 8, the same player may keep playing from hand:
# another 8, any queen, or a card matching the top discard suit.
# Playing another 8 continues the chain; other legal plays end the chain and pass turn.
module EightFollowupService
  class << self
    def continues_chain?(card_code)
      Game::Card.parse(card_code).eight?
    end
  end
end
