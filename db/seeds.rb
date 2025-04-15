puts "Creating topics..."
# Create initial topics
topics = ['Technology', 'Science', 'Business', 'Health', 'Sports', 'Politics', 'Entertainment', 'World']
topics.each do |topic|
  Topic.find_or_create_by(name: topic.downcase)
end

puts "Creating email metrics..."

# Make sure we have some users first
unless User.exists?
  puts "Creating sample users first..."
  5.times do |i|
    User.create!(
      email: "user#{i+1}@example.com",
      password: "password123",
      confirmed_at: Time.current,
      is_subscribed: true
    )
  end
end

# Email types and statuses - use only valid statuses from the model
EMAIL_TYPES = ['daily_digest', 'weekly_summary']
EMAIL_STATUSES = ['sent', 'opened', 'clicked', 'failed']  # These are the correct statuses

# Create email metrics for each user
User.find_each do |user|
  # Create metrics for the last 30 days
  30.times do |i|
    # Create 1-3 email metrics per day
    rand(1..3).times do
      EmailMetric.create!(
        user: user,
        email_type: EMAIL_TYPES.sample,
        status: EMAIL_STATUSES.sample,
        subject: [
          "Your Daily News Digest for #{30 - i} days ago",
          "Weekly News Roundup - Week of #{30 - i} days ago",
          "Top Stories from Your Selected Sources"
        ].sample,
        sent_at: (30 - i).days.ago + rand(0..23).hours,
        created_at: (30 - i).days.ago,
        updated_at: (30 - i).days.ago
      )
    end
  end
end

# Create some email tracking records
User.find_each do |user|
  # Create tracking for the last 7 days
  7.times do |i|
    EmailTracking.create!(
      user: user,
      open_count: rand(0..5),
      click_count: rand(0..3),
      created_at: (7 - i).days.ago,
      updated_at: (7 - i).days.ago
    )
  end
end

puts "Created #{EmailMetric.count} email metrics"
puts "Created #{EmailTracking.count} email tracking records"