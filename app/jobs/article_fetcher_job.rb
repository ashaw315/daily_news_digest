class ArticleFetcherJob < ApplicationJob
  queue_as :default
  
  def perform(options = {})
    Rails.logger.info("Starting ArticleFetcherJob")
    
    fetcher = EnhancedNewsFetcher.new(options)
    articles = fetcher.fetch_articles
    
    Rails.logger.info("ArticleFetcherJob completed: fetched #{articles.count} articles")
  end
end 