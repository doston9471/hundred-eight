# frozen_string_literal: true

class Room < ApplicationRecord
  MIN_PLAYERS = 2
  MAX_PLAYERS = 5

  enum :status, { waiting: 0, active: 1, finished: 2 }

  belongs_to :host, class_name: "User"
  belongs_to :last_round_loser, class_name: "RoomPlayer", optional: true, foreign_key: :last_round_loser_room_player_id
  has_many :room_players, -> { order(:seat) }, dependent: :destroy, inverse_of: :room
  has_many :users, through: :room_players
  has_many :invite_tokens, dependent: :destroy
  has_many :rounds, dependent: :destroy

  validates :name, length: { maximum: 80 }, allow_blank: true

  def current_round
    rounds.status_in_progress.order(number: :desc).first
  end

  def latest_round
    rounds.order(number: :desc).first
  end

  def between_rounds?
    active? && current_round.nil? && rounds.status_completed.exists?
  end

  def host?(user)
    user && host_id == user.id
  end

  def full?
    room_players.count >= MAX_PLAYERS
  end

  def player_count_in_bounds?
    c = room_players.count
    c >= MIN_PLAYERS && c <= MAX_PLAYERS
  end

  def active_non_eliminated_players
    room_players.where(eliminated: false)
  end
end
