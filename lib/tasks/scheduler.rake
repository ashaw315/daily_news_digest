namespace :scheduler do
  desc "Schedule daily email jobs for all users who want daily digests"
  task schedule_daily_emails: :environment do
    start_time = Time.current
    initial_memory = get_memory_usage_mb
    Rails.logger.info("[Scheduler] Starting daily email scheduling - Memory: #{initial_memory}MB")
    
    # Memory safety constants
    BATCH_SIZE = 25              # Process users in small batches
    MEMORY_THRESHOLD_MB = 400    # Pause if memory gets high
    GC_FREQUENCY = 10            # Force GC every N batches
    
    begin
      # Find users who want daily digests and are subscribed
      users_scope = User.where(is_subscribed: true)
                       .where("preferences->>'frequency' = ?", 'daily')
                       .select(:id, :email, :preferences)  # Only load needed columns
      
      total_users = users_scope.count
      Rails.logger.info("[Scheduler] Found #{total_users} users for daily emails")
      
      if total_users == 0
        Rails.logger.info("[Scheduler] No users to process")
        return
      end
      
      count = 0
      batch_count = 0
      failed_count = 0
      
      # Process in memory-safe batches
      users_scope.find_in_batches(batch_size: BATCH_SIZE) do |user_batch|
        batch_count += 1
        batch_start_memory = get_memory_usage_mb
        
        Rails.logger.info("[Scheduler] Processing batch #{batch_count} (#{user_batch.size} users) - Memory: #{batch_start_memory}MB")
        
        # Memory safety check
        if batch_start_memory > MEMORY_THRESHOLD_MB
          Rails.logger.warn("[Scheduler] Memory high (#{batch_start_memory}MB), forcing GC")
          GC.start
          post_gc_memory = get_memory_usage_mb
          Rails.logger.info("[Scheduler] After GC: #{batch_start_memory}MB → #{post_gc_memory}MB")
          
          # If still high after GC, pause briefly
          if post_gc_memory > MEMORY_THRESHOLD_MB
            Rails.logger.warn("[Scheduler] Memory still high after GC, pausing 2 seconds")
            sleep(2)
          end
        end
        
        # Schedule jobs for this batch
        user_batch.each do |user|
          begin
            DailyEmailJob.perform_later(user)
            count += 1
          rescue => e
            Rails.logger.error("[Scheduler] Failed to schedule job for user #{user.id}: #{e.message}")
            failed_count += 1
          end
        end
        
        # Periodic garbage collection
        if (batch_count % GC_FREQUENCY).zero?
          GC.start
          batch_end_memory = get_memory_usage_mb
          Rails.logger.info("[Scheduler] Batch #{batch_count} completed - Memory: #{batch_start_memory}MB → #{batch_end_memory}MB")
        end
        
        # Brief pause between batches to prevent overwhelming
        sleep(0.1) if Rails.env.production?
      end
      
      # Final statistics
      final_memory = get_memory_usage_mb
      total_time = (Time.current - start_time).round(2)
      
      Rails.logger.info("[Scheduler] Daily email scheduling completed:")
      Rails.logger.info("  Total time: #{total_time}s")
      Rails.logger.info("  Users processed: #{count}")
      Rails.logger.info("  Failed jobs: #{failed_count}")
      Rails.logger.info("  Batches processed: #{batch_count}")
      Rails.logger.info("  Memory: #{initial_memory}MB → #{final_memory}MB")
      Rails.logger.info("  Success rate: #{((count.to_f / total_users) * 100).round(1)}%")
      
    rescue => e
      error_memory = get_memory_usage_mb
      Rails.logger.error("[Scheduler] Critical error during daily email scheduling at #{error_memory}MB: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.first(3).join(' | ')}")
      raise e
    ensure
      # Final cleanup
      GC.start
      cleanup_memory = get_memory_usage_mb
      Rails.logger.info("[Scheduler] Final cleanup - Memory: #{cleanup_memory}MB")
    end
  end
  
  desc "Schedule weekly email jobs for all users who want weekly digests"
  task schedule_weekly_emails: :environment do
    # Find users who want weekly digests and are subscribed
    users = User.where(is_subscribed: true)
                .where("preferences->>'frequency' = ?", 'weekly')
    
    count = 0
    users.find_each do |user|
      WeeklyEmailJob.perform_later(user)
      count += 1
    end
    
    Rails.logger.info("Scheduled #{count} weekly email jobs")
  end

  desc "Fetch latest articles for all active news sources"
  task fetch_articles: :environment do
    sources = NewsSource.where(active: true)
    fetcher = EnhancedNewsFetcher.new(sources: sources)
    fetcher.fetch_articles
    puts "Fetched articles for #{sources.count} sources."
  end
  
  # Helper method for memory monitoring
  def get_memory_usage_mb
    rss_kb = `ps -o rss= -p #{Process.pid}`.to_i
    (rss_kb / 1024.0).round(2)
  rescue => e
    Rails.logger.error("[Scheduler] Memory monitoring error: #{e.message}")
    0.0
  end
end 