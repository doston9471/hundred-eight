# frozen_string_literal: true

class InviteTokenIssuer
  class << self
    def call!(room:, expires_in: 7.days)
      raw = SecureRandom.urlsafe_base64(32)
      room.invite_tokens.create!(token_digest: InviteToken.digest(raw), expires_at: Time.current + expires_in)
      raw
    end
  end
end
