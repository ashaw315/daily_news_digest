FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:name) { |n| "User #{n}" }
    password { 'password123' }
    password_confirmation { 'password123' }
    preferences { { 'topics' => [], 'sources' => [], 'frequency' => 'daily' } }
    is_subscribed { true }
    confirmed_at { Time.current }
    unsubscribe_token { SecureRandom.urlsafe_base64(32) }

    trait :subscribed do
      is_subscribed { true }
    end

    trait :unconfirmed do
      confirmed_at { nil }
    end
  end
end