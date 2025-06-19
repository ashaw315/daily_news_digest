# Preview all emails at http://localhost:3000/rails/mailers/daily_news_mailer
require 'ostruct'
class DailyNewsMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/daily_news_mailer/daily_digest
  def daily_digest
    # Create a unique user for the preview
    timestamp = "#{Time.now.to_i}_#{Time.now.nsec}"
    user = User.new(
      email: "preview_#{timestamp}@example.com",
      password: 'password123',
      name: 'Preview User',
      is_subscribed: true,
      unsubscribe_token: SecureRandom.urlsafe_base64(32)
    )
    user.save!(validate: false)

    # Ensure the user has a Preferences record
    user.create_preferences!(email_frequency: 'daily', dark_mode: false) unless user.preferences

    # Assign news sources (pick 2 random ones)
    sources = NewsSource.limit(2)
    user.news_sources = sources
    user.save!(validate: false)

    # Create sample articles
    articles = [
      OpenStruct.new(
        title: 'Sample Tech Article',
        description: 'This is a sample technology article for preview purposes.',
        source: 'Tech News',
        url: 'https://example.com/tech',
        published_at: 1.day.ago,
        topic: 'technology'
      ),
      OpenStruct.new(
        title: 'Sample Sports Article',
        description: 'This is a sample sports article for preview purposes.',
        source: 'Sports News',
        url: 'https://example.com/sports',
        published_at: 2.days.ago,
        topic: 'sports'
      )
    ]

    # Return the mailer preview
    DailyNewsMailer.daily_digest(user, articles)
  end

  # Remove the weekly_digest preview (no longer used)
end