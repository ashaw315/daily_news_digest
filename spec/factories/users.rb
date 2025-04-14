FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:name) { |n| "User #{n}" }
    password { 'password123' }
    password_confirmation { 'password123' }
    is_subscribed { true }
    confirmed_at { Time.current }
    unsubscribe_token { SecureRandom.urlsafe_base64(32) }
    admin { false }

    # trait :subscribed do
    #   is_subscribed { true }
    # end

    # trait :unconfirmed do
    #   confirmed_at { nil }
    # end

    # Remove this callback if you're relying on the User model's callback
    # after(:create) do |user|
    #   create(:preferences, user: user)
    # end
    trait :admin do
      admin { true }
    end
  end
end