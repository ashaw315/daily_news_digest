class WeeklyEmailJob < ApplicationJob
  queue_as :mailers
  
  # Retry with exponential backoff, but wait at least 1 hour between retries
  retry_on StandardError, wait: 1.hour, attempts: 3, jitter: 0.15
  
  # After 3 failures, discard the job and purge the user
  discard_on StandardError do |job, error|
    user = job.arguments.first
    
    if user && user.is_a?(User)
      Rails.logger.error("Email delivery failed 3 times for user #{user.id} (#{user.email}). Purging user record.")
      Rails.logger.error("Error: #{error.message}")
      
      # Purge the user from the database
      user.destroy
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
    
    # Send the email
    DailyNewsMailer.weekly_digest(user, articles).deliver_now
    
    Rails.logger.info("Successfully sent weekly news digest to user #{user.id} (#{user.email})")
  end
end