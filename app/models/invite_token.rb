# frozen_string_literal: true

class InviteToken < ApplicationRecord
  belongs_to :room

  validates :token_digest, presence: true, uniqueness: true

  def self.digest(raw)
    Digest::SHA256.hexdigest(raw)
  end

  def self.find_room_for_raw!(raw)
    dig = digest(raw)
    token = includes(:room).find_by(token_digest: dig)
    raise ActiveRecord::RecordNotFound unless token
    raise ActiveRecord::RecordNotFound if token.expires_at && token.expires_at < Time.current

    token.room
  end
end
