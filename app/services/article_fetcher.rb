class ArticleFetcher
  def self.fetch_for_user(user)
    # Get user preferences
    topics = user.preferences&.dig('topics') || []
    preferred_source = user.preferred_news_source
    
    # Create options for the fetcher
    options = {
      topics: topics.presence,
      preferred_source: preferred_source,
      max_articles: 10
    }
    
    # Fetch personalized articles
    fetcher = EnhancedNewsFetcher.new(options)
    articles = fetcher.fetch_news_of_the_day_brief
    
    # Convert to match your schema if needed
    articles.map do |article|
      if article.is_a?(OpenStruct)
        # Convert OpenStruct to match your schema
        article.summary = article.description if article.respond_to?(:description)
        article.publish_date = article.published_at if article.respond_to?(:published_at)
      end
      article
    end
  end
end 