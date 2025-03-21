FactoryBot.define do
  factory :api do
    sequence(:name) { |n| "API #{n}" }
    sequence(:endpoint) { |n| "https://api#{n}.example.com" }
    priority { 0 }
  end
end