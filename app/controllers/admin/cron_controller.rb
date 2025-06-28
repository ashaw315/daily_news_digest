class Admin::CronController < Admin::BaseController
  # Skip base controller authentications for API access
  skip_before_action :authenticate_user!, only: [:purge_articles, :fetch_articles, :schedule_daily_emails]
  skip_before_action :require_admin, only: [:purge_articles, :fetch_articles, :schedule_daily_emails]
  skip_before_action :verify_authenticity_token, only: [:purge_articles, :fetch_articles, :schedule_daily_emails]
  
  # Add our own authentication for API/admin access
  before_action :authenticate_cron_or_admin
  before_action :check_task_lock, only: [:fetch_articles, :schedule_daily_emails]
  
  def purge_articles
    cutoff = 24.hours.ago
    deleted = Article.where("created_at < ?", cutoff).delete_all
    
    track_cron_metric("purge_articles", { deleted_count: deleted })
    Rails.logger.info "[CRON] Purged #{deleted} articles older than 24 hours"
    render_success("Successfully deleted #{deleted} articles older than 24 hours")
  end

  def fetch_articles
    Rails.logger.info "[CRON] Starting article fetch at #{Time.current}"
    
    with_task_lock("fetch_articles") do
      Rake::Task['scheduler:fetch_articles'].reenable
      Rake::Task['scheduler:fetch_articles'].invoke
      
      track_cron_metric("fetch_articles")
      Rails.logger.info "[CRON] Articles fetch completed at #{Time.current}"
      render_success("Articles fetch task completed successfully")
    end
  rescue => e
    Rails.logger.error "[CRON] Articles fetch failed: #{e.full_message}"
    render_error("Articles fetch failed", e)
  end

  def schedule_daily_emails
    Rails.logger.info "[CRON] Starting daily email scheduling at #{Time.current}"
    
    with_task_lock("schedule_daily_emails") do
      Rake::Task['scheduler:schedule_daily_emails'].reenable
      Rake::Task['scheduler:schedule_daily_emails'].invoke
      
      track_cron_metric("schedule_daily_emails")
      Rails.logger.info "[CRON] Daily emails scheduled at #{Time.current}"
      render_success("Daily emails scheduled successfully")
    end
  rescue => e
    Rails.logger.error "[CRON] Daily email scheduling failed: #{e.full_message}"
    render_error("Daily email scheduling failed", e)
  end

  private

  def authenticate_cron_or_admin
    api_key = request.headers['X-API-KEY'] || params[:api_key]
    
    if api_key.present?
      unless ActiveSupport::SecurityUtils.secure_compare(api_key, ENV['CRON_API_KEY'].to_s)
        render_error("Unauthorized", status: :unauthorized)
        return false
      end
    else
      authenticate_user!
      unless current_user&.admin?
        redirect_to root_path, alert: "You are not authorized to access this area"
        return false
      end
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
      timestamp: Time.current
    }
    
    respond_to do |format|
      format.json { render json: response }
      format.html { render plain: message }
    end
  end

  def render_error(message, error = nil, status: 500)
    response = {
      status: "error",
      message: message,
      details: Rails.env.development? ? error&.full_message : nil,
      timestamp: Time.current
    }.compact

    Rails.logger.error("[CRON] #{message}: #{error&.full_message}")
    
    respond_to do |format|
      format.json { render json: response, status: status }
      format.html { render plain: message, status: status }
    end
  end
end