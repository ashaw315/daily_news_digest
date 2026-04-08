class DailyEmailJob < ApplicationJob
  queue_as :mailers
  
  # Memory safety constants
  MEMORY_LIMIT_MB = 450        # Hard limit to prevent overflow
  AI_PROCESSING_LIMIT = 30     # Max articles to process with AI (3 per source × 10 sources)
  
  # Retry with exponential backoff, but wait at least 1 hour between retries
  retry_on StandardError, wait: 1.hour, attempts: 3, jitter: 0.15
  
  # After 3 failures, discard the job and unsubscribe the user
  discard_on StandardError do |job, error|
    user = job.arguments.first

    if user && user.is_a?(User)
      Rails.logger.error("Email delivery failed 3 times for user #{user.id} (#{user.email}). Unsubscribing user.")
      Rails.logger.error("Error: #{error.message}")

      user.unsubscribe!
    else
      Rails.logger.error("Email delivery failed 3 times but couldn't identify user. Error: #{error.message}")
    end
  end
  
  def perform(user)
    start_time = Time.current
    initial_memory = get_memory_usage_mb
    Rails.logger.info("[DailyEmailJob] Starting for user #{user.id} - Memory: #{initial_memory}MB")
    
    begin
      # Skip if user is not subscribed
      return unless user.is_subscribed
      
      # Skip if user prefers weekly emails
      return unless user.email_frequency == 'daily'
      
      # Memory safety check
      if initial_memory > MEMORY_LIMIT_MB
        Rails.logger.error("[DailyEmailJob] Memory too high: #{initial_memory}MB, skipping user #{user.id}")
        return
      end
      
      # Fetch articles with memory monitoring
      pre_fetch_memory = get_memory_usage_mb
      articles = ArticleFetcher.fetch_for_user(user)
      post_fetch_memory = get_memory_usage_mb
      
      Rails.logger.info("[DailyEmailJob] Article fetch: #{pre_fetch_memory}MB → #{post_fetch_memory}MB")
      
      # Process articles with AI summarization in memory-safe batches
      if articles.present?
        processed_articles = process_articles_with_ai_safely(articles, user.id)
        
        # Memory check before email generation
        pre_email_memory = get_memory_usage_mb
        if pre_email_memory > MEMORY_LIMIT_MB
          Rails.logger.warn("[DailyEmailJob] Memory high before email: #{pre_email_memory}MB")
          GC.start
          post_gc_memory = get_memory_usage_mb
          Rails.logger.info("[DailyEmailJob] After GC: #{pre_email_memory}MB → #{post_gc_memory}MB")
        end
        
        # Create tracking record for open tracking
        tracking = create_tracking_record(user)

        # Send the email with processed articles
        DailyNewsMailer.daily_digest(user, processed_articles, tracking&.token).deliver_now

        # Record successful send metric
        record_metric(user, "daily", "sent")

        # Add delay to prevent Gmail rate limiting (500 emails/day limit)
        sleep(1) if Rails.env.production?

        final_memory = get_memory_usage_mb
        total_time = (Time.current - start_time).round(2)

        Rails.logger.info("[DailyEmailJob] Completed user #{user.id} in #{total_time}s - Memory: #{initial_memory}MB → #{final_memory}MB")
      else
        Rails.logger.info("[DailyEmailJob] No articles for user #{user.id}")
      end
      
    rescue => e
      error_memory = get_memory_usage_mb
      Rails.logger.error("[DailyEmailJob] Error for user #{user.id} at #{error_memory}MB: #{e.message}")
      record_metric(user, "daily", "failed")
      raise e
    ensure
      # Force cleanup
      GC.start if Rails.env.production?
    end
  end
  
  private
  
  def process_articles_with_ai_safely(articles, user_id)
    return articles if articles.empty?
    
    # Limit articles for AI processing to prevent memory overflow
    limited_articles = articles.take(AI_PROCESSING_LIMIT)
    Rails.logger.info("[DailyEmailJob] Processing #{limited_articles.size} articles with AI for user #{user_id}")
    
    pre_ai_memory = get_memory_usage_mb
    
    # Use sequential processing for memory safety in production
    processor = ParallelArticleProcessor.new
    processed_articles = processor.process_articles(limited_articles)
    
    post_ai_memory = get_memory_usage_mb
    Rails.logger.info("[DailyEmailJob] AI processing: #{pre_ai_memory}MB → #{post_ai_memory}MB")
    
    # Clean up processor
    processor = nil
    GC.start if Rails.env.production?
    
    processed_articles
  rescue => e
    Rails.logger.error("[DailyEmailJob] AI processing error for user #{user_id}: #{e.message}")
    # Return original articles without AI summaries as fallback
    articles.map do |article|
      {
        title: article[:title] || article['title'] || 'Untitled',
        summary: article[:summary] || article['summary'] || article[:title] || 'No summary available',
        url: article[:url] || article['url'] || '',
        published_at: article[:published_at] || article['published_at'] || Time.current,
        source: article[:source] || article['source'] || 'Unknown'
      }
    end
  end
  
  def create_tracking_record(user)
    EmailTracking.create!(user: user, open_count: 0, click_count: 0)
  rescue => e
    Rails.logger.error("[DailyEmailJob] Failed to create tracking record: #{e.message}")
    nil
  end

  def record_metric(user, email_type, status)
    EmailMetric.create!(
      user: user,
      email_type: email_type,
      status: status,
      subject: "Your Daily News Digest - #{Date.today.strftime('%B %d, %Y')}",
      sent_at: Time.current
    )
  rescue => e
    Rails.logger.error("[DailyEmailJob] Failed to record metric: #{e.message}")
  end

  def get_memory_usage_mb
    rss_kb = `ps -o rss= -p #{Process.pid}`.to_i
    (rss_kb / 1024.0).round(2)
  rescue => e
    Rails.logger.error("[DailyEmailJob] Memory monitoring error: #{e.message}")
    0.0
  end
end