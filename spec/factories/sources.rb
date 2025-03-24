FactoryBot.define do
    factory :source do
      sequence(:name) { |n| "Test Source #{n}" }
      sequence(:url) { |n| "https://example.com/source-#{n}" }
      source_type { "rss" }
      active { true }
      selectors { {} }
      
      trait :rss do
        source_type { "rss" }
      end
      
      trait :api do
        source_type { "api" }
      end
      
      trait :scrape do
        source_type { "scrape" }
        selectors { {
          article: ".article",
          title: "h2",
          content: ".content",
          published_at: ".date"
        } }
      end
    end
  end