# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :room_players, dependent: :destroy
  has_many :rooms, through: :room_players
  has_many :hosted_rooms, class_name: "Room", foreign_key: :host_id, inverse_of: :host, dependent: :destroy

  generates_token_for :password_reset, expires_in: 15.minutes do
    password_digest&.last(10)
  end

  normalizes :email, with: ->(e) { e.strip.downcase }
  normalizes :username, with: ->(n) { n.to_s.strip }

  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :email, presence: true, uniqueness: true
  validates :password, allow_nil: true, length: { minimum: 8 }

  def password_reset_token
    generate_token_for(:password_reset)
  end

  def self.find_by_password_reset_token!(token)
    find_by_token_for(:password_reset, token) || raise(ActiveSupport::MessageVerifier::InvalidSignature)
  end
end
