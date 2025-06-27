# Use this file to easily define all of your cron jobs.
# Learn more: http://github.com/javan/whenever

# Set the environment
set :environment, ENV['RAILS_ENV'] || 'development'
set :output, 'log/cron.log'

# Fetch articles at 7 AM
every 1.day, at: '7:00 am' do
  rake "scheduler:fetch_articles"
end

# Schedule daily emails at 8 AM
every 1.day, at: '8:00 am' do
  rake "scheduler:schedule_daily_emails"
end

# Schedule weekly emails at 9 AM on Sundays
every :friday, at: '8:00 am' do
  rake "scheduler:schedule_weekly_emails"
end

every 1.day, at: '2:00 am' do
  rake "admin:purge_old_articles"
end