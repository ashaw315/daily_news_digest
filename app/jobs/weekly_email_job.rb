class WeeklyEmailJob < ApplicationJob
  queue_as :mailers
  
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
    # Skip if user is not subscribed
    return unless user.is_subscribed
    
    # Skip if user prefers daily emails
    return unless user.email_frequency == 'weekly'
    
    Rails.logger.info("Sending weekly news digest to user #{user.id} (#{user.email})")
    
    # Fetch articles based on user preferences (with days: 7)
    articles = ArticleFetcher.fetch_for_user(user, days: 7)

    # Create tracking record for open tracking
    tracking = create_tracking_record(user)

    # Send the email
    DailyNewsMailer.weekly_digest(user, articles, tracking&.token).deliver_now

    # Record successful send metric
    record_metric(user, "weekly")

    Rails.logger.info("Successfully sent weekly news digest to user #{user.id} (#{user.email})")
  rescue => e
    record_metric(user, "weekly", "failed")
    raise e
  end

  private

  def create_tracking_record(user)
    EmailTracking.create!(user: user, open_count: 0, click_count: 0)
  rescue => e
    Rails.logger.error("[WeeklyEmailJob] Failed to create tracking record: #{e.message}")
    nil
  end

  def record_metric(user, email_type, status = "sent")
    EmailMetric.create!(
      user: user,
      email_type: email_type,
      status: status,
      subject: "Your Weekly News Digest - #{Date.today.strftime('%B %d, %Y')}",
      sent_at: Time.current
    )
  rescue => e
    Rails.logger.error("[WeeklyEmailJob] Failed to record metric: #{e.message}")
  end
end