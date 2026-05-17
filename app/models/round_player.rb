# frozen_string_literal: true

class RoundPlayer < ApplicationRecord
  belongs_to :round
  belongs_to :room_player

  has_many :card_plays, dependent: :destroy

  validates :room_player_id, uniqueness: { scope: :round_id }

  def hand_codes
    Array(hand)
  end
end
