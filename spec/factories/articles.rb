FactoryBot.define do
  factory :article do
    sequence(:title) { |n| "Article Title #{n}" }
    sequence(:url) { |n| "https://example.com/article-#{n}" }
    summary { "Article summary" }
    publish_date { Time.current }
    topic { "general" }
    association :news_source
  end
end