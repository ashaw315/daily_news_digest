require 'concurrent-ruby'
require 'timeout'

# ParallelArticleProcessor - Fast parallel processing for up to 30 articles
# Maintains existing AI summary format while processing articles from all user sources
class ParallelArticleProcessor
  # Hard limits and configuration optimized for 512MB
  MAX_ARTICLES = 30              # Hard limit - process up to 30 articles (3 per source × 10 sources)
  MAX_THREADS = Rails.env.production? ? 1 : ENV.fetch('PARALLEL_MAX_THREADS', 2).to_i  # Sequential in production
  MIN_THREADS = Rails.env.production? ? 1 : ENV.fetch('PARALLEL_MIN_THREADS', 1).to_i
  ARTICLE_TIMEOUT = ENV.fetch('PARALLEL_TIMEOUT', 8).to_i  # 8 seconds per article
  
  attr_reader :errors, :performance_stats
  
  def initialize
    @errors = []
    @performance_stats = {}
    @start_time = Time.current
    
    # Create thread pool for parallel execution
    @thread_pool = Concurrent::FixedThreadPool.new(
      MAX_THREADS,
      min_threads: MIN_THREADS,
      max_threads: MAX_THREADS,
      max_queue: MAX_ARTICLES * 2,
      fallback_policy: :caller_runs
    )
    
    log_memory_usage("Parallel processor initialized")
    Rails.logger.info("PARALLEL: Thread pool created (#{MIN_THREADS}-#{MAX_THREADS} threads)")
  end
  
  # Main processing method - processes up to 30 articles in parallel
  def process_articles(articles)
    start_time = Time.current
    log_memory_usage("Starting parallel processing")
    
    # HARD LIMIT: Never process more than 30 articles
    articles = articles.take(MAX_ARTICLES)
    Rails.logger.info("PARALLEL: Processing #{articles.length} articles (max #{MAX_ARTICLES})")
    
    if articles.empty?
      Rails.logger.warn("PARALLEL: No articles to process")
      return []
    end
    
    # Create futures for parallel execution
    futures = articles.map.with_index do |article, index|
      create_article_future(article, index)
    end
    
    # Wait for all futures with timeout
    processed_articles = []
    # In production (sequential), allow more time. In development (parallel), shorter timeout per article
    multiplier = Rails.env.production? ? articles.length : 2
    total_timeout = (ARTICLE_TIMEOUT * multiplier) + 10  # Extra buffer time
    
    begin
      Timeout.timeout(total_timeout) do
        futures.each_with_index do |future, index|
          begin
            result = future.value(ARTICLE_TIMEOUT)
            processed_articles << result if result
            Rails.logger.info("PARALLEL: Article #{index + 1} completed")
          rescue Concurrent::TimeoutError => e
            @errors << "Article #{index + 1} timed out after #{ARTICLE_TIMEOUT}s"
            Rails.logger.error("PARALLEL: Article #{index + 1} timeout")
            processed_articles << create_fallback_article(articles[index], index, "timeout")
          rescue => e
            @errors << "Article #{index + 1} error: #{e.message}"
            Rails.logger.error("PARALLEL: Article #{index + 1} error: #{e.message}")
            processed_articles << create_fallback_article(articles[index], index, e.message)
          end
        end
      end
    rescue Timeout::Error => e
      @errors << "Global processing timeout after #{total_timeout}s"
      Rails.logger.error("PARALLEL: Global timeout")
    end
    
    # Calculate performance statistics
    end_time = Time.current
    total_duration = (end_time - start_time) * 1000  # milliseconds
    
    @performance_stats = {
      total_duration_ms: total_duration.round(2),
      articles_processed: processed_articles.length,
      articles_requested: articles.length,
      success_rate: articles.length > 0 ? ((processed_articles.length.to_f / articles.length) * 100).round(2) : 0,
      avg_time_per_article_ms: articles.length > 0 ? (total_duration / articles.length).round(2) : 0,
      parallel_efficiency: calculate_parallel_efficiency(total_duration, articles.length),
      errors_count: @errors.length
    }
    
    Rails.logger.info("PARALLEL COMPLETE: #{@performance_stats[:total_duration_ms]}ms total, #{@performance_stats[:success_rate]}% success")
    log_memory_usage("Parallel processing completed")
    
    processed_articles
    
  rescue => e
    @errors << "Critical parallel processing error: #{e.message}"
    Rails.logger.error("PARALLEL CRITICAL ERROR: #{e.message}")
    []
  ensure
    cleanup_resources
  end
  
  # Create a future for processing a single article
  def create_article_future(article, index)
    Concurrent::Future.execute(executor: @thread_pool) do
      article_start_time = Time.current
      
      begin
        Rails.logger.info("PARALLEL: Starting article #{index + 1}")
        
        # Use SHARED AI summarizer instance to reduce memory
        summarizer = @@shared_summarizer ||= AiSummarizerService.new
        
        # Extract article data maintaining existing format
        processed_article = {
          title: extract_title(article),
          url: extract_url(article),
          published_at: extract_published_date(article),
          source: extract_source(article)
        }
        
        # Get content for AI processing
        content = extract_content(article)
        
        # Generate AI summary using existing service with timeout
        summary = nil
        begin
          Timeout.timeout(ARTICLE_TIMEOUT - 1) do  # Leave 1 second buffer
            summary = summarizer.generate_summary(content, 100)  # Use existing parameters
          end
        rescue Timeout::Error => e
          Rails.logger.warn("PARALLEL: AI timeout for article #{index + 1}")
          summary = generate_fallback_summary(content)
        rescue => e
          Rails.logger.error("PARALLEL: AI error for article #{index + 1}: #{e.message}")
          summary = generate_fallback_summary(content)
        end
        
        processed_article[:summary] = summary || generate_fallback_summary(content)
        
        # Add processing metadata
        processing_time = ((Time.current - article_start_time) * 1000).round(2)
        processed_article[:processing_time_ms] = processing_time
        
        # Force memory cleanup after each article in production
        if Rails.env.production?
          GC.start
        end
        
        Rails.logger.info("PARALLEL: Article #{index + 1} completed in #{processing_time}ms")
        processed_article
        
      rescue => e
        Rails.logger.error("PARALLEL: Article #{index + 1} future error: #{e.message}")
        raise e
      end
    end
  end
  
  # Memory monitoring
  def log_memory_usage(context)
    memory_mb = get_memory_usage_mb
    @performance_stats[:memory_usage] ||= {}
    @performance_stats[:memory_usage][context] = memory_mb
    
    Rails.logger.info("PARALLEL MEMORY [#{context}]: #{memory_mb}MB")
    memory_mb
  end
  
  def get_memory_usage_mb
    rss_kb = `ps -o rss= -p #{Process.pid}`.to_i
    (rss_kb / 1024.0).round(2)
  rescue => e
    Rails.logger.error("Memory monitoring error: #{e.message}")
    0.0
  end
  
  # Resource cleanup
  def cleanup_resources
    Rails.logger.info("PARALLEL: Cleaning up resources")
    
    begin
      # Shutdown thread pool gracefully
      @thread_pool&.shutdown
      @thread_pool&.wait_for_termination(5)
      
      # Force garbage collection
      GC.start
      
      log_memory_usage("After cleanup")
      Rails.logger.info("PARALLEL: Resource cleanup completed")
      
    rescue => e
      Rails.logger.error("PARALLEL: Cleanup error: #{e.message}")
    end
  end
  
  private
  
  # Article data extraction methods maintaining existing format
  def extract_title(article)
    case article
    when Hash
      article[:title] || article['title'] || "Untitled Article"
    else
      article.respond_to?(:title) ? article.title : "Untitled Article"
    end.to_s.strip
  end
  
  def extract_url(article)
    case article
    when Hash
      article[:url] || article['url'] || article[:link] || article['link'] || ""
    else
      url = article.respond_to?(:url) ? article.url : nil
      url ||= article.respond_to?(:link) ? article.link : ""
      url.to_s.strip
    end
  end
  
  def extract_content(article)
    case article
    when Hash
      content = article[:content] || article['content'] || 
                article[:summary] || article['summary'] ||
                article[:description] || article['description'] ||
                article[:title] || article['title']
    else
      content = article.respond_to?(:content) ? article.content : nil
      content ||= article.respond_to?(:summary) ? article.summary : nil
      content ||= article.respond_to?(:description) ? article.description : nil
      content ||= article.respond_to?(:title) ? article.title : ""
    end
    
    content.to_s.strip
  end
  
  def extract_published_date(article)
    case article
    when Hash
      article[:published_at] || article['published_at'] ||
      article[:pub_date] || article['pub_date'] ||
      article[:date] || article['date'] || Time.current
    else
      date = article.respond_to?(:published_at) ? article.published_at : nil
      date ||= article.respond_to?(:published) ? article.published : nil
      date ||= article.respond_to?(:pub_date) ? article.pub_date : nil
      date || Time.current
    end
  end
  
  def extract_source(article)
    case article
    when Hash
      article[:source] || article['source'] || 
      article[:source_name] || article['source_name'] || "Unknown"
    else
      source = article.respond_to?(:source) ? article.source : nil
      source ||= article.respond_to?(:source_name) ? article.source_name : "Unknown"
      source.to_s.strip
    end
  end
  
  # Generate fallback summary using existing format (first 150 chars + "...")
  def generate_fallback_summary(content)
    return "Summary not available" if content.blank?
    
    # Use existing fallback format from AI summarizer
    if content.length > 150
      content[0..147] + "..."
    else
      content
    end
  end
  
  # Create fallback article when processing fails
  def create_fallback_article(original_article, index, error_message)
    {
      title: extract_title(original_article),
      url: extract_url(original_article),
      published_at: extract_published_date(original_article),
      source: extract_source(original_article),
      summary: "Article processing #{error_message == 'timeout' ? 'timed out' : 'failed'}. Please try again.",
      processing_time_ms: ARTICLE_TIMEOUT * 1000,
      error: error_message
    }
  end
  
  # Calculate parallel processing efficiency
  def calculate_parallel_efficiency(total_duration_ms, article_count)
    return 0 if article_count == 0
    
    # Theoretical sequential time (estimated 7 seconds per article)
    theoretical_sequential_ms = article_count * 7000
    efficiency = ((theoretical_sequential_ms - total_duration_ms) / theoretical_sequential_ms * 100).round(2)
    [efficiency, 0].max  # Don't show negative efficiency
  end
end