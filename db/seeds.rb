puts "Creating topics..."
# Create initial topics
topics = ['Technology', 'Science', 'Business', 'Health', 'Sports', 'Politics', 'Entertainment', 'World']
topic_records = topics.map do |topic|
  Topic.find_or_create_by!(name: topic.downcase)
end

puts "Creating news sources..."
# Create news sources and associate with topics
news_sources_data = [
  { name: "CNN", url: "https://rss.cnn.com/rss/cnn_topstories.rss", topic: "world" },
  { name: "BBC", url: "https://feeds.bbci.co.uk/news/rss.xml", topic: "world" },
  { name: "Reuters", url: "https://www.reutersagency.com/feed/", topic: "business" },
  { name: "TechCrunch", url: "https://techcrunch.com/feed/", topic: "technology" },
  { name: "ESPN", url: "https://www.espn.com/espn/rss/news", topic: "sports" },
  { name: "The Verge", url: "https://www.theverge.com/rss/index.xml", topic: "technology" },
  { name: "Healthline", url: "https://www.healthline.com/rss", topic: "health" },
  { name: "Hollywood Reporter", url: "https://www.hollywoodreporter.com/t/rss", topic: "entertainment" }
]

news_sources = news_sources_data.map do |data|
  topic = Topic.find_by(name: data[:topic])
  NewsSource.find_or_create_by!(
    name: data[:name],
    url: data[:url],
    format: "rss",
    active: true,
    topic: topic
  )
end

puts "Creating sample users..."
if User.count == 0
  5.times do |i|
    user = User.create!(
      email: "user#{i+1}@example.com",
      password: "password123",
      confirmed_at: Time.current,
      is_subscribed: true
    )
    # Assign 1-3 random news sources to each user
    user.news_sources = news_sources.sample(rand(1..3))
    user.save!
  end
end

puts "Creating email metrics..."

EMAIL_TYPES = ['daily_digest']
EMAIL_STATUSES = ['sent', 'opened', 'clicked', 'failed']

User.find_each do |user|
  30.times do |i|
    rand(1..3).times do
      EmailMetric.create!(
        user: user,
        email_type: EMAIL_TYPES.sample,
        status: EMAIL_STATUSES.sample,
        subject: [
          "Your Daily News Digest for #{30 - i} days ago",
          "Top Stories from Your Selected Sources"
        ].sample,
        sent_at: (30 - i).days.ago + rand(0..23).hours,
        created_at: (30 - i).days.ago,
        updated_at: (30 - i).days.ago
      )
    end
  end
end

puts "Creating email tracking records..."

User.find_each do |user|
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

puts "Created #{Topic.count} topics"
puts "Created #{NewsSource.count} news sources"
puts "Created #{User.count} users"
puts "Created #{EmailMetric.count} email metrics"
puts "Created #{EmailTracking.count} email tracking records"