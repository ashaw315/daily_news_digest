FactoryBot.define do
    factory :news_source do
      sequence(:name) { |n| "News Source #{n}" }
      url { "https://example.com/news" }
      format { "api" }
      active { true }
      settings { {} }
    end
  end