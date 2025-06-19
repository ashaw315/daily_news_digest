class ArticleFetcher
  def self.fetch_for_user(user, days: 1)
    # Get user's selected news sources (limit to 15)
    source_ids = user.news_source_ids.take(15)
    sources = NewsSource.where(id: source_ids)

    # Create options for the fetcher
    options = {
      sources: sources,
      max_articles: 50,
      days: days
    }

    # Fetch personalized articles
    fetcher = EnhancedNewsFetcher.new(options)
    articles = fetcher.fetch_articles

    articles
  end
end