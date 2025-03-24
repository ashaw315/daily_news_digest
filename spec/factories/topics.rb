FactoryBot.define do
    factory :topic do
      sequence(:name) { |n| "topic_#{n}" }
      active { true }
    end
  end