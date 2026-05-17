# frozen_string_literal: true

FactoryBot.define do
  factory :session do
    user
    ip_address { "127.0.0.1" }
    user_agent { "RSpec" }
  end

  factory :invite_token do
    room
    expires_at { 1.day.from_now }
    token_digest { InviteToken.digest(SecureRandom.urlsafe_base64(16)) }
  end

  factory :round do
    room
    sequence(:number) { |n| n }
    status { :in_progress }
    phase { "normal" }
    draw_pile { [] }
    discard_pile { [ "7|hearts" ] }
    turn_order { [] }
    current_turn_index { 0 }
    required_suit { nil }
  end

  factory :round_player do
    round
    room_player
    hand { [] }
  end

  factory :card_play do
    round
    round_player
    kind { :play }
    card_code { "7|hearts" }
    metadata { {} }
  end

  factory :score_entry do
    round
    room_player
    points { 0 }
    bonus_points { 0 }
  end
end
