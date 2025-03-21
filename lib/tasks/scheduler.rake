namespace :scheduler do
  desc "Schedule daily email jobs for all users who want daily digests"
  task schedule_daily_emails: :environment do
    # Find users who want daily digests and are subscribed
    users = User.where(is_subscribed: true)
                .where("preferences->>'frequency' = ?", 'daily')
    
    count = 0
    users.find_each do |user|
      DailyEmailJob.perform_later(user)
      count += 1
    end
    
    Rails.logger.info("Scheduled #{count} daily email jobs")
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
end 