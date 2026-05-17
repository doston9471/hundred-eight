# frozen_string_literal: true

class ScoreEntry < ApplicationRecord
  belongs_to :round
  belongs_to :room_player
end
