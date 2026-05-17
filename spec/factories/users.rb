# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "player#{n}" }
    sequence(:email) { |n| "player#{n}@example.test" }
    password { "password12" }
    password_confirmation { "password12" }
  end

  factory :room do
    association :host, factory: :user
    status { :waiting }
    name { "Test room" }

    after(:create) do |room|
      room.room_players.create!(user: room.host, seat: 0) unless room.room_players.exists?(user_id: room.host_id)
    end

    trait :with_guest do
      after(:create) do |room|
        next if room.room_players.count >= 2

        room.room_players.create!(user: create(:user), seat: 1)
      end
    end

    trait :active do
      status { :active }
    end
  end

  factory :room_player do
    room
    user
    sequence(:seat) { |n| n }
    eliminated { false }
    total_score { 0 }
    online { false }
  end
end
