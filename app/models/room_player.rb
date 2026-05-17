# frozen_string_literal: true

class RoomPlayer < ApplicationRecord
  belongs_to :room
  belongs_to :user

  has_many :round_players, dependent: :destroy
  has_many :score_entries, dependent: :destroy

  validates :seat, presence: true, uniqueness: { scope: :room_id }

  def mark_online!
    update!(online: true, last_seen_at: Time.current)
  end

  def mark_offline!
    update!(online: false, last_seen_at: Time.current)
  end
end
