# Preview all emails at http://localhost:3000/rails/mailers/daily_news_mailer
class DailyNewsMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/daily_news_mailer/daily_digest
  def daily_digest
    # Create a completely new user for the preview with a more unique email
    timestamp = "#{Time.now.to_i}_#{Time.now.nsec}"
    user = User.new(
      email: "preview_#{timestamp}@example.com",
      password: 'password123',
      name: 'Preview User',
      preferences: { 'topics' => ['technology', 'sports'] },
      is_subscribed: true,
      unsubscribe_token: SecureRandom.urlsafe_base64(32)
    )
    
    # Save without validations to ensure it works
    user.save(validate: false)
    
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

  # Preview this email at http://localhost:3000/rails/mailers/daily_news_mailer/weekly_digest
  def weekly_digest
    # Create a completely new user for the preview with a more unique email
    timestamp = "#{Time.now.to_i}_#{Time.now.nsec}"
    user = User.new(
      email: "preview_weekly_#{timestamp}@example.com",
      password: 'password123',
      name: 'Preview User',
      preferences: { 'topics' => ['technology', 'sports'] },
      is_subscribed: true,
      unsubscribe_token: SecureRandom.urlsafe_base64(32)
    )
    
    # Save without validations to ensure it works
    user.save(validate: false)
    
    articles = [
      OpenStruct.new(
        title: 'Weekly Tech Roundup',
        description: 'This is a weekly technology roundup for preview purposes.',
        source: 'Tech Weekly',
        url: 'https://example.com/tech-weekly',
        published_at: 5.days.ago,
        topic: 'technology'
      ),
      OpenStruct.new(
        title: 'Sports Week in Review',
        description: 'This is a weekly sports review for preview purposes.',
        source: 'Sports Weekly',
        url: 'https://example.com/sports-weekly',
        published_at: 6.days.ago,
        topic: 'sports'
      )
    ]
    
    DailyNewsMailer.weekly_digest(user, articles)
  end
end
