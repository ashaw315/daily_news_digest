FactoryBot.define do
  factory :news_source do
    sequence(:name) { |n| "News Source #{n}" }
    url { "https://example.com/feed" }
    format { "rss" }
    active { true }
    settings { {} }
    association :topic
  end
end