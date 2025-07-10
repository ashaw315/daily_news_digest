require 'digest'

# CachedEnhancedNewsFetcher - Fast caching layer for EnhancedNewsFetcher
# Enforces hard limit of 3 articles maximum and adds intelligent caching
class CachedEnhancedNewsFetcher < EnhancedNewsFetcher
  # Hard limits and caching configuration
  MAX_ARTICLES_PER_SOURCE = 3        # Hard limit - never fetch more than 3
  CACHE_TTL = ENV.fetch('RSS_CACHE_TTL', 300).to_i  # 5 minutes
  MAX_CACHE_SIZE = ENV.fetch('MAX_CACHE_SIZE', 50).to_i
  
  def initialize(options = {})
    super(options)
    @cache = Rails.cache.respond_to?(:write) ? Rails.cache : SimpleMemoryCache.new
    @cache_stats = { hits: 0, misses: 0, requests: 0 }
    
    # Override any max_articles setting to enforce our hard limit
    @options[:max_articles] = MAX_ARTICLES_PER_SOURCE
    
    Rails.logger.info("CACHED FETCHER: Initialized with #{@sources.length} sources (max #{MAX_ARTICLES_PER_SOURCE} articles each)")
  end
  
  def fetch_articles
    fetch_start_time = Time.current
    Rails.logger.info("CACHED FETCH: Starting for #{@sources.length} sources")
    
    all_articles = []
    
    @sources.each do |source|
      begin
        source_start_time = Time.current
        
        # Try to get cached articles first
        cached_articles = get_cached_articles(source)
        
        if cached_articles
          @cache_stats[:hits] += 1
          all_articles.concat(cached_articles)
          Rails.logger.info("CACHE HIT: #{source.name} (#{cached_articles.length} articles)")
        else
          @cache_stats[:misses] += 1
          Rails.logger.info("CACHE MISS: #{source.name} - fetching fresh")
          
          # Fetch fresh articles using parent class
          source_articles = fetch_fresh_articles_for_source(source)
          
          if source_articles.present?
            # Cache the results
            cache_articles_for_source(source, source_articles)
            all_articles.concat(source_articles)
            update_source_stats(source, 'success', source_articles.length)
          else
            update_source_stats(source, 'no_articles', 0)
          end
        end
        
        source_duration = ((Time.current - source_start_time) * 1000).round(2)
        Rails.logger.info("CACHED FETCH: #{source.name} completed in #{source_duration}ms")
        
      rescue => e
        Rails.logger.error("CACHED FETCH: Error with #{source.name}: #{e.message}")
        update_source_stats(source, 'error', 0)
      end
    end
    
    # Log cache performance
    total_duration = ((Time.current - fetch_start_time) * 1000).round(2)
    log_cache_performance(total_duration)
    
    # ENFORCE HARD LIMIT: Never return more than 3 articles total
    final_articles = all_articles.take(MAX_ARTICLES_PER_SOURCE)
    Rails.logger.info("CACHED FETCH COMPLETE: #{final_articles.length}/#{MAX_ARTICLES_PER_SOURCE} articles in #{total_duration}ms")
    
    final_articles
  end
  
  private
  
  # Get cached articles for a source
  def get_cached_articles(source)
    @cache_stats[:requests] += 1
    cache_key = generate_cache_key(source)
    
    cached_data = @cache.read(cache_key)
    
    if cached_data && cache_fresh?(cached_data[:timestamp])
      Rails.logger.debug("CACHE HIT: #{source.name}")
      cached_data[:articles]
    else
      Rails.logger.debug("CACHE MISS: #{source.name}")
      nil
    end
  end
  
  # Cache articles for a source
  def cache_articles_for_source(source, articles)
    cache_key = generate_cache_key(source)
    
    # ENFORCE LIMIT: Only cache first 3 articles
    articles_to_cache = articles.take(MAX_ARTICLES_PER_SOURCE)
    
    cache_data = {
      articles: articles_to_cache,
      timestamp: Time.current,
      source_id: source.id,
      source_name: source.name
    }
    
    @cache.write(cache_key, cache_data, expires_in: CACHE_TTL)
    Rails.logger.debug("CACHED: #{source.name} (#{articles_to_cache.length} articles)")
    
    # Manage cache size
    cleanup_old_cache_entries if @cache.respond_to?(:delete)
  end
  
  # Fetch fresh articles for a single source
  def fetch_fresh_articles_for_source(source)
    begin
      # Use parent class method but with enforced limits
      feed = fetch_feed(source.url)
      
      # Get only the first 3 most recent entries (HARD LIMIT)
      recent_entries = feed.entries
        .sort_by { |entry| entry.published || Time.current }
        .reverse
        .first(MAX_ARTICLES_PER_SOURCE)  # ENFORCE LIMIT HERE
      
      source_articles = recent_entries.map do |entry|
        fetch_from_rss_and_summarize(entry, source.name)
      end.compact
      
      # DOUBLE-CHECK LIMIT: Ensure we never return more than 3
      source_articles.take(MAX_ARTICLES_PER_SOURCE)
      
    rescue => e
      Rails.logger.error("FRESH FETCH ERROR for #{source.name}: #{e.message}")
      []
    end
  end
  
  # Generate cache key for a source
  def generate_cache_key(source)
    "news_articles_#{Digest::MD5.hexdigest("#{source.id}_#{source.url}_#{source.updated_at}")}"
  end
  
  # Check if cached data is still fresh
  def cache_fresh?(timestamp)
    timestamp && (Time.current - timestamp) < CACHE_TTL
  end
  
  # Performance logging
  def log_cache_performance(total_duration)
    if (@cache_stats[:requests] % 5).zero?  # Log every 5 requests
      hit_rate = @cache_stats[:requests] > 0 ? (@cache_stats[:hits].to_f / @cache_stats[:requests] * 100).round(2) : 0
      
      Rails.logger.info("CACHE PERFORMANCE:")
      Rails.logger.info("  Duration: #{total_duration}ms")
      Rails.logger.info("  Requests: #{@cache_stats[:requests]}")
      Rails.logger.info("  Hits: #{@cache_stats[:hits]}")
      Rails.logger.info("  Misses: #{@cache_stats[:misses]}")
      Rails.logger.info("  Hit rate: #{hit_rate}%")
    end
  end
  
  # Cache cleanup
  def cleanup_old_cache_entries
    # Simple cleanup - this would be more sophisticated in a real cache implementation
    Rails.logger.debug("CACHE: Cleanup triggered")
  end
end

# Simple memory cache implementation when Rails.cache is not available
class SimpleMemoryCache
  def initialize
    @cache = {}
    @last_cleanup = Time.current
  end
  
  def read(key)
    cleanup_if_needed
    entry = @cache[key]
    
    if entry && entry[:expires_at] > Time.current
      entry[:value]
    else
      @cache.delete(key)
      nil
    end
  end
  
  def write(key, value, options = {})
    expires_in = options[:expires_in] || 300  # 5 minutes default
    @cache[key] = {
      value: value,
      expires_at: Time.current + expires_in
    }
    
    # Prevent memory bloat
    cleanup_if_needed
  end
  
  def delete(key)
    @cache.delete(key)
  end
  
  private
  
  def cleanup_if_needed
    # Cleanup every 5 minutes
    if Time.current - @last_cleanup > 300
      cleanup
      @last_cleanup = Time.current
    end
  end
  
  def cleanup
    current_time = Time.current
    @cache.delete_if { |_key, entry| entry[:expires_at] <= current_time }
    
    # Limit cache size to MAX_CACHE_SIZE
    if @cache.size > CachedEnhancedNewsFetcher::MAX_CACHE_SIZE
      sorted_entries = @cache.sort_by { |_key, entry| entry[:expires_at] }
      @cache = sorted_entries.last(CachedEnhancedNewsFetcher::MAX_CACHE_SIZE / 2).to_h
    end
  end
end