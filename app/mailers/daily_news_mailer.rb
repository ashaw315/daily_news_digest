class DailyNewsMailer < ApplicationMailer
  default from: "news@dailynewsdigest.com"
  helper MailerHelper

  def daily_digest(user, articles)
    @user = user
    
    # Get recent articles from subscribed sources
    articles_from_db = Article
      .includes(:news_source)  # Make sure to include news_source
      .where(news_source_id: user.news_source_ids)
      .where('publish_date >= ?', 48.hours.ago)
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
  
    # Group by news source's topic, handling nil topics
    @articles_by_topic = @articles.group_by do |article|
      if article.news_source&.topic
        article.news_source.topic.name
      else
        "Other" # Default category for articles without a topic
      end
    end.transform_values { |arts| arts.sort_by(&:publish_date).reverse }
  
    # Sort topics alphabetically, ensuring "Other" comes last if present
    @sorted_topics = @articles_by_topic.keys.compact.sort do |a, b|
      if a == "Other"
        1
      elsif b == "Other"
        -1
      else
        a <=> b
      end
    end
  
    mail(
      to: @user.email,
      subject: "Your Daily News Digest - #{Date.today.strftime('%B %d, %Y')}"
    )
  end

  def newsletter(user)
    @user = user
    
    # Get articles from user's subscribed sources
    articles_from_db = Article
      .includes(:news_source)  # Make sure to include news_source
      .where(news_source_id: user.news_source_ids)
      .where('publish_date >= ?', 24.hours.ago)
      .order(publish_date: :desc)

    # Group by source and take top 3 most recent from each
    articles_by_source = articles_from_db.group_by(&:news_source_id)
    @articles = articles_by_source.values.flat_map do |source_articles|
      source_articles
        .sort_by(&:publish_date)
        .reverse
        .take(3)
    end

    # Group by news source's topic
    @articles_by_topic = @articles
      .group_by { |article| article.news_source.topic.name }
      .transform_values { |arts| arts.sort_by(&:publish_date).reverse }

    # Sort topics alphabetically
    @sorted_topics = @articles_by_topic.keys.compact.sort

    mail(
      to: @user.email,
      subject: "Your Daily News Digest - #{Date.today.strftime('%B %d, %Y')}"
    )
  end
end