#!/usr/bin/env ruby
# Quick test script to verify article fetching behavior

require_relative 'config/environment'

# Find a user with subscriptions
user = User.find_by(admin: true) || User.first

puts "=== Testing Article Fetcher Logic ==="
puts "User: #{user.email}"
puts "Subscribed to #{user.news_sources.count} sources:"

user.news_sources.each do |source|
  article_count = Article.where(news_source: source).count
  puts "  - #{source.name}: #{article_count} total articles"
end

puts "\n=== Testing ArticleFetcher.fetch_for_user ==="
articles = ArticleFetcher.fetch_for_user(user)
puts "Total articles returned: #{articles.size}"

# Group by source to see distribution
if articles.present?
  articles_by_source = articles.group_by { |article| 
    if article.is_a?(Hash)
      article[:source] || article['source']
    else
      article.source
    end
  }
  
  puts "\nArticles per source:"
  articles_by_source.each do |source_name, source_articles|
    puts "  - #{source_name}: #{source_articles.size} articles"
  end
else
  puts "No articles returned"
end

puts "\n=== Expected: 3 articles per subscribed source ==="
puts "Expected total: #{user.news_sources.count * 3} articles"