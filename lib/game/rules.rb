# frozen_string_literal: true

module Game
  class Rules
    def self.legal_normal_play?(hand_codes, play_code, top_code, required_suit:, phase:)
      card = Card.parse(play_code)
      top = Card.parse(top_code)
      return false unless hand_codes.include?(play_code)

      case phase.to_s
      when "eight_followup"
        return true if card.queen?
        return true if card.eight?
        return false unless card.same_suit?(top)

        true
      when "ace_tail"
        card.matches_discard?(top, required_suit: required_suit)
      when "normal", "queen_pick_suit"
        card.matches_discard?(top, required_suit: required_suit)
      else
        false
      end
    end

    def self.any_legal_play?(hand_codes, top_code, required_suit:, phase:)
      hand_codes.any? { |c| legal_normal_play?(hand_codes, c, top_code, required_suit: required_suit, phase: phase) }
    end

    def self.legal_seven_response?(hand_codes, play_code, top_code)
      return false unless hand_codes.include?(play_code)

      card = Card.parse(play_code)
      top = Card.parse(top_code)
      card.seven? && top.seven?
    end

    def self.consecutive_sevens_from_top(discard_pile)
      n = 0
      discard_pile.reverse_each do |code|
        break unless Card.parse(code).seven?

        n += 1
      end
      n
    end

    def self.illegal_finishing_card?(_play_code)
      false
    end
  end
end
