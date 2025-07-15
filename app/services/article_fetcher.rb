class ArticleFetcher
  # Memory-optimized limits for 512MB environment
  MAX_SOURCES_PER_USER = 10        # Reduced from 15
  MAX_ARTICLES_PER_USER = 15       # Reduced from 50
  MEMORY_THRESHOLD_MB = 400        # Alert threshold
  
  def self.fetch_for_user(user, days: 1)
    start_memory = get_memory_usage_mb
    Rails.logger.info("[ArticleFetcher] Starting for user #{user.id} - Memory: #{start_memory}MB")
    
    begin
      # Get user's selected news sources with stricter limits
      source_ids = user.news_source_ids.take(MAX_SOURCES_PER_USER)
      sources = NewsSource.where(id: source_ids).includes(:topic)

      # Memory-optimized fetcher options
      options = {
        sources: sources,
        max_articles: MAX_ARTICLES_PER_USER,
        days: days,
        summarize: false  # Skip summarization during fetch to save memory
      }

      # Check memory before fetching
      pre_fetch_memory = get_memory_usage_mb
      if pre_fetch_memory > MEMORY_THRESHOLD_MB
        Rails.logger.warn("[ArticleFetcher] Memory high before fetch: #{pre_fetch_memory}MB")
        GC.start
      end

      # Fetch articles with memory-safe fetcher
      fetcher = EnhancedNewsFetcher.new(options)
      articles = fetcher.fetch_articles || []
      
      # Force cleanup after fetch
      fetcher = nil
      GC.start if Rails.env.production?
      
      post_fetch_memory = get_memory_usage_mb
      Rails.logger.info("[ArticleFetcher] Completed for user #{user.id} - Memory: #{start_memory}MB → #{post_fetch_memory}MB")
      
      # Get exactly 3 articles per source (instead of limiting total)
      articles_per_source = get_articles_per_source(sources)
      Rails.logger.info("[ArticleFetcher] Retrieved #{articles_per_source.sum(&:size)} articles from #{sources.size} sources")
      
      articles_per_source.flatten
      
    rescue => e
      Rails.logger.error("[ArticleFetcher] Error for user #{user.id}: #{e.message}")
      []
    end
  end
  
  private
  
  def self.get_articles_per_source(sources)
    articles_per_source = []
    
    sources.each do |source|
      # Get exactly 3 most recent articles from this source
      source_articles = Article.where(news_source: source)
                              .order(publish_date: :desc)
                              .limit(3)
                              .to_a
      
      Rails.logger.info("[ArticleFetcher] Source #{source.name}: #{source_articles.size} articles")
      articles_per_source << source_articles
    end
    
    articles_per_source
  end
  
  def self.get_memory_usage_mb
    rss_kb = `ps -o rss= -p #{Process.pid}`.to_i
    (rss_kb / 1024.0).round(2)
  rescue => e
    Rails.logger.error("[ArticleFetcher] Memory monitoring error: #{e.message}")
    0.0
  end
end