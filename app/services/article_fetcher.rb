class ArticleFetcher
  def self.fetch_for_user(user, days: 1)
    # Get user's selected news sources (limit to 15)
    source_ids = user.news_source_ids.take(15)
    sources = NewsSource.where(id: source_ids)

    # Create options for the fetcher
    options = {
      sources: sources,
      max_articles: 50, # or whatever makes sense for your digest
      days: days
    }

    # Fetch personalized articles
    fetcher = EnhancedNewsFetcher.new(options)
    articles = fetcher.fetch_news_of_the_day_brief

    # Convert to match your schema if needed
    articles.map do |article|
      if article.is_a?(OpenStruct)
        article.summary = article.description if article.respond_to?(:description)
        article.publish_date = article.published_at if article.respond_to?(:published_at)
      end
      article
    end
  end
end