class ArticleFetcher
  def self.fetch_for_user(user, days: 1)
    # Get user's selected topics
    topics = user.topics.pluck(:name)
    
    # Get user's preferred source (if any)
    preferred_source = user.preferences&.preferred_source
    
    # Create options for the fetcher
    options = {
      topics: topics.presence,
      preferred_source: preferred_source,
      max_articles: 10,
      days: days
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