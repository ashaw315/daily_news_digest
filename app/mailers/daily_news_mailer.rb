class DailyNewsMailer < ApplicationMailer
  default from: "news@dailynewsdigest.com"
  helper MailerHelper

  def daily_digest(user, articles)
    @user = user
    
    # Get recent articles from subscribed sources
    articles_from_db = Article
      .includes(:news_source)
      .where(news_source_id: user.news_source_ids)
      .where('publish_date >= ?', 48.hours.ago)  # Increased time window
      .order(publish_date: :desc)
    
    # Group by source and take top 3 most recent from each
    articles_by_source = articles_from_db.group_by(&:news_source_id)
    @articles = articles_by_source.values.flat_map do |source_articles|
      source_articles
        .sort_by(&:publish_date)
        .reverse
        .take(3)  # Take 3 most recent from each source
    end
  
    puts "\n=== Article Distribution in Email ==="
    @articles.group_by(&:news_source).each do |source, articles|
      puts "#{source&.name || 'Unknown'}: #{articles.length} articles"
      articles.each do |article|
        puts "  - #{article.title} (#{article.summary&.length || 0} chars)"
      end
    end
  
    # Then organize by topic for display
    @articles_by_topic = @articles
      .group_by { |article| article.topic || "Other" }
      .transform_values { |arts| arts.sort_by(&:publish_date).reverse }
  
    @sorted_topics = @articles_by_topic.keys.compact.sort
  
    mail(
      to: @user.email,
      subject: "Your Daily News Digest - #{Date.today.strftime('%B %d, %Y')}"
    )
  end

  def weekly_digest(user, articles)
    @user = user
    
    # Similar logic as daily digest but with more articles per source
    articles_by_source = articles.group_by(&:news_source_id)
    limited_articles = articles_by_source.values.flat_map do |source_articles|
      source_articles
        .sort_by { |a| a.publish_date || Time.current }
        .reverse
        .take(5) # Take 5 for weekly digest
    end

    @articles_by_topic = limited_articles
      .group_by { |article| article.topic || "Other" }
      .transform_values { |arts| arts.sort_by { |a| a.publish_date || Time.current }.reverse }

    @sorted_topics = @articles_by_topic.keys.compact.sort

    mail(
      to: @user.email,
      subject: "Your Weekly News Digest - #{Date.today.strftime('%B %d, %Y')}"
    )
  end

  def newsletter(user)
    @user = user
    
    # Get articles from user's subscribed sources
    articles = Article
      .where(news_source_id: user.news_source_ids)
      .where('publish_date >= ?', 24.hours.ago)
      .includes(:news_source)
      .order(publish_date: :desc)

    # Limit to 3 per source
    articles_by_source = articles.group_by(&:news_source_id)
    @articles = articles_by_source.values.flat_map { |source_articles| source_articles.take(3) }

    mail(
      to: @user.email,
      subject: "Your Daily News Digest - #{Date.today.strftime('%B %d, %Y')}"
    )
  end
end