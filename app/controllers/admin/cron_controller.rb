require 'timeout'

class Admin::CronController < Admin::BaseController
  # Skip base controller authentications for API access
  skip_before_action :authenticate_user!, only: [:purge_articles, :fetch_articles, :schedule_daily_emails, :health]
  skip_before_action :require_admin, only: [:purge_articles, :fetch_articles, :schedule_daily_emails, :health]
  skip_before_action :verify_authenticity_token, only: [:purge_articles, :fetch_articles, :schedule_daily_emails, :health]
  
  # Add our own authentication for API/admin access
  before_action :log_cron_request, except: [:health]
  before_action :authenticate_cron_or_admin, except: [:health]
  
  def purge_articles
    Rails.logger.info "[CRON] Purge articles started - IP: #{request.remote_ip}, User-Agent: #{request.user_agent}"
    start_time = Time.current
    
    begin
      cutoff = 24.hours.ago
      deleted = Article.where("created_at < ?", cutoff).delete_all
      
      duration = (Time.current - start_time).round(2)
      track_cron_metric("purge_articles", { deleted_count: deleted, duration_seconds: duration })
      Rails.logger.info "[CRON] Purged #{deleted} articles older than 24 hours in #{duration}s"
      render_success("Successfully deleted #{deleted} articles older than 24 hours in #{duration}s")
    rescue => e
      Rails.logger.error "[CRON] Article purge failed: #{e.full_message}"
      render_error("Article purge failed", e)
    end
  end

  def fetch_articles
    Rails.logger.info "[CRON] Article fetch started - IP: #{request.remote_ip}, User-Agent: #{request.user_agent}"
    start_time = Time.current
    
    # Add overall timeout to prevent hanging
    timeout_result = Timeout.timeout(300) do  # 5 minute timeout
      with_task_lock("fetch_articles") do
      # Get only news sources that have subscribed users
      active_sources = NewsSource.joins(:users)
                                .where(users: { is_subscribed: true })
                                .where(active: true)
                                .where.not(url: [nil, ''])
                                .distinct
  
      if active_sources.empty?
        Rails.logger.info "[CRON] No active sources with subscribed users found"
        return render_success("No active sources with subscribed users found")
      end
      
      subscribed_users_count = User.joins(:news_sources)
                                  .where(is_subscribed: true)
                                  .where(news_sources: { id: active_sources.pluck(:id) })
                                  .distinct
                                  .count
  
      # Track how many sources we're fetching from
      source_count = active_sources.count
      Rails.logger.info "[CRON] Fetching articles from #{source_count} active sources for #{subscribed_users_count} subscribed users"
  
      fetcher = EnhancedNewsFetcher.new(sources: active_sources)
      articles = fetcher.fetch_articles || []
      
      # Return a concise success message with counts
      duration = (Time.current - start_time).round(2)
      track_cron_metric("fetch_articles", {
        source_count: source_count,
        article_count: articles.length,
        duration_seconds: duration
      })
      
      Rails.logger.info "[CRON] Articles fetch completed in #{duration}s. Fetched #{articles.length} articles from #{source_count} sources for #{subscribed_users_count} subscribed users"
      render_success("Fetched #{articles.length} articles from #{source_count} sources for #{subscribed_users_count} subscribed users in #{duration}s")
      end
    end
    
    timeout_result
  rescue Timeout::Error => e
    Rails.logger.error "[CRON] Articles fetch timed out after 5 minutes"
    render_error("Articles fetch timed out", e)
  rescue => e
    Rails.logger.error "[CRON] Articles fetch failed: #{e.full_message}"
    render_error("Articles fetch failed", e)
  end

  def schedule_daily_emails
    Rails.logger.info "[CRON] Email scheduling started - IP: #{request.remote_ip}, User-Agent: #{request.user_agent}"
    start_time = Time.current
    
    with_task_lock("schedule_daily_emails") do
      begin
        # Find users who want daily digests and are subscribed
        users_scope = User.joins(:preferences)
                         .where(is_subscribed: true)
                         .where('preferences.email_frequency = ?', 'daily')
      
      total_users = users_scope.count
      Rails.logger.info "[CRON] Found #{total_users} users for daily emails"
      
      if total_users == 0
        Rails.logger.info "[CRON] No users to process"
        duration = (Time.current - start_time).round(2)
        track_cron_metric("schedule_daily_emails", { duration_seconds: duration, users_count: 0 })
        return render_success("No users to process for daily emails in #{duration}s")
      end
      
      count = 0
      failed_count = 0
      
      # Schedule jobs for users
      users_scope.find_each do |user|
        begin
          DailyEmailJob.perform_later(user)
          count += 1
        rescue => e
          Rails.logger.error "[CRON] Failed to schedule job for user #{user.id}: #{e.message}"
          failed_count += 1
        end
      end
      
      duration = (Time.current - start_time).round(2)
      track_cron_metric("schedule_daily_emails", { 
        duration_seconds: duration, 
        users_count: count,
        failed_count: failed_count
      })
      
        Rails.logger.info "[CRON] Daily emails scheduled in #{duration}s - #{count} users, #{failed_count} failures"
        render_success("Daily emails scheduled for #{count} users in #{duration}s (#{failed_count} failures)")
      rescue => e
        Rails.logger.error "[CRON] Daily email scheduling failed: #{e.full_message}"
        render_error("Daily email scheduling failed", e)
      end
    end
  end

  def health
    render json: { 
      status: 'ok', 
      timestamp: Time.current.iso8601,
      service: 'daily-news-digest'
    }
  end

  private

  def log_cron_request
    Rails.logger.info "[CRON] Job triggered: #{action_name} at #{Time.current}"
    Rails.logger.info "[CRON] User Agent: #{request.user_agent}"
    Rails.logger.info "[CRON] IP: #{request.remote_ip}"
    Rails.logger.info "[CRON] Method: #{request.method}"
  end

  def authenticate_cron_or_admin
    api_key = request.headers['X-API-KEY'] || params[:api_key]
    
    if api_key.present?
      unless ActiveSupport::SecurityUtils.secure_compare(api_key, ENV['CRON_API_KEY'].to_s)
        render_error("Unauthorized", status: :unauthorized)
        return false
      end
    else
      # For API endpoints, return 401 instead of redirecting
      render_error("API key required", status: :unauthorized)
      return false
    end
  end

  def with_task_lock(task_name)
    lock_key = "cron_lock:#{task_name}"
    
    if Rails.cache.exist?(lock_key)
      render_error("Task #{task_name} is already running", status: :conflict)
      return
    end
    
    Rails.cache.write(lock_key, true, expires_in: 30.minutes)
    begin
      yield
    ensure
      Rails.cache.delete(lock_key)
    end
  end

  def track_cron_metric(task_name, additional_data = {})
    metric_data = {
      timestamp: Time.current,
      task: task_name,
      source: api_request? ? 'api' : 'web'
    }.merge(additional_data)

    Rails.cache.write(
      "cron_metrics:#{task_name}:last_run",
      metric_data,
      expires_in: 1.week
    )
  end

  def api_request?
    request.headers['X-API-KEY'].present? || params[:api_key].present?
  end

  def render_success(message)
    response = {
      status: "success",
      message: message,
      timestamp: Time.current.iso8601
    }
    
    if defined?(@_response) && @_response
      render json: response
    else
      # When running from rake task
      puts "\nSuccess: #{message}"
      puts "Timestamp: #{Time.current.iso8601}"
    end
  end
  
  def render_error(message, error = nil, status: 500)
    response = {
      status: "error",
      message: message,
      timestamp: Time.current.iso8601
    }
  
    if defined?(@_response) && @_response
      render json: response, status: status
    else
      # When running from rake task
      puts "\nError: #{message}"
      puts "Timestamp: #{Time.current.iso8601}"
      puts "Details: #{error.full_message}" if error && Rails.env.development?
    end
  end
end