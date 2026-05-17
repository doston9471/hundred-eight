# frozen_string_literal: true

class CardPlay < ApplicationRecord
  enum :kind, { play: 0, draw: 1, suit_choice: 2, pass: 3 }, prefix: true

  belongs_to :round
  belongs_to :round_player

  scope :for_history, -> { where(kind: %i[play pass suit_choice]) }
end
