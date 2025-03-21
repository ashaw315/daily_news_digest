class EnhancedNewsFetcher
  def initialize(options = {})
    @options = options
    @rotator = SourceRotator.new
    @fetcher = NewsFetcher.new(options)
  end
  
  def fetch_articles
    # Get prioritized sources
    prioritized_sources = @rotator.prioritized_sources
    
    # If user has preferred source for News of the Day Brief, prioritize it
    if @options[:preferred_source].present?
      prioritized_sources.unshift(@options[:preferred_source]) 
      prioritized_sources.uniq!
    end
    
    # Update fetcher with prioritized sources
    sources = @fetcher.sources.sort_by do |source|
      prioritized_sources.index(source[:name]) || Float::INFINITY
    end
    
    @fetcher.instance_variable_set(:@sources, sources)
    
    # Fetch articles with timing
    articles = []
    sources.each do |source|
      start_time = Time.now
      success = false
      
      begin
        new_articles = fetch_from_source(source)
        articles.concat(new_articles)
        success = true
      rescue => e
        Rails.logger.error("Error fetching from #{source[:name]}: #{e.message}")
      end
      
      # Record stats
      response_time = Time.now - start_time
      @rotator.update_source_stats(source[:name], success, response_time)
      
      # If we have enough articles, stop fetching
      break if articles.length >= (@options[:max_articles] || 50)
    end
    
    articles
  end
  
  def fetch_news_of_the_day_brief(count = 5)
    # Fetch articles with preference for user's preferred source
    articles = fetch_articles
    
    # Select top articles based on recency and source preference
    articles.sort_by do |article|
      # Newer articles get higher priority
      recency_score = article.published_at.to_i
      
      # Preferred source gets a boost
      source_boost = article.source == @options[:preferred_source] ? 1.day.to_i : 0
      
      recency_score + source_boost
    end.take(count)
  end
  
  private
  
  def fetch_from_source(source)
    case source[:type]
    when :rss
      @fetcher.send(:fetch_from_rss, source)
    when :api
      @fetcher.send(:fetch_from_api, source)
    when :scrape
      @fetcher.send(:fetch_from_scraper, source)
    else
      []
    end
  end
end 