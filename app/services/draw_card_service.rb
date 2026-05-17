# frozen_string_literal: true

class DrawCardService
  class << self
    # Caller must hold `round.with_lock` when concurrent updates matter.
    def draw_one!(round, round_player:)
      replenish_if_empty!(round)
      round.reload
      return nil if round.draw_pile.blank?

      code = round.draw_pile.shift
      round.save!
      rp = round_player.reload
      rp.update!(hand: rp.hand_codes + [ code ])
      code
    end

    def draw_n!(round, round_player:, count:)
      drawn = []
      count.times do
        code = draw_one!(round.reload, round_player: round_player.reload)
        break unless code

        drawn << code
      end
      drawn
    end

    def replenish_if_empty!(round)
      return if round.draw_pile.any?
      return if round.discard_pile.size < 2

      top = round.discard_pile.last
      rest = round.discard_pile[0...-1].shuffle
      round.update!(discard_pile: [ top ], draw_pile: rest)
    end

    # Read-only: whether a player could draw at least one card (pile or reshuffle from discards).
    def draw_would_be_available?(round)
      round = round.reload
      round.draw_pile.any? || round.discard_pile.size >= 2
    end
  end
end
