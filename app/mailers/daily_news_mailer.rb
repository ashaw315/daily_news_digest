class DailyNewsMailer < ApplicationMailer
  default from: ENV['EMAIL_FROM_ADDRESS'] || "ashaw315@gmail.com"  # Use verified SendGrid sender email
  helper MailerHelper

  def daily_digest(user, articles)
    initial_memory = get_memory_usage_mb
    Rails.logger.info("[DailyNewsMailer] Starting email generation - Memory: #{initial_memory}MB")
    
    @user = user
    
    # Memory-safe article processing
    if articles.present?
      # Convert to standardized format and limit count
      @articles = normalize_articles(articles).take(15)  # Hard limit for email size
      
      Rails.logger.info("[DailyNewsMailer] Processing #{@articles.size} articles for #{@user.email}")
      
      # Memory-efficient grouping without duplicating data
      @articles_by_topic = create_topic_groups(@articles)
      @sorted_topics = sort_topics(@articles_by_topic.keys)
      
      # Log article distribution without storing extra data
      log_article_distribution(@articles) if Rails.env.development?
    else
      @articles = []
      @articles_by_topic = {}
      @sorted_topics = []
    end
    
    final_memory = get_memory_usage_mb
    Rails.logger.info("[DailyNewsMailer] Email prepared - Memory: #{initial_memory}MB → #{final_memory}MB")
  
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

  def weekly_digest(user, articles)
    @user = user
    @articles = articles
    @articles_by_topic = @articles
      .group_by { |article| article.news_source&.topic&.name || "Other" }
      .transform_values { |arts| arts.sort_by(&:publish_date).reverse }
    @sorted_topics = @articles_by_topic.keys.compact.sort

    mail(
      to: @user.email,
      subject: "Your Daily News Digest - #{Date.today.strftime('%B %d, %Y')}"
    )
  end
  
  private
  
  # Normalize articles to consistent format and free memory
  def normalize_articles(articles)
    articles.map do |article|
      # Handle both hash and object formats
      normalized = case article
      when Hash
        {
          title: article[:title] || article['title'] || 'Untitled',
          summary: article[:summary] || article['summary'] || '',
          url: article[:url] || article['url'] || '',
          published_at: article[:published_at] || article['published_at'] || Time.current,
          source: article[:source] || article['source'] || 'Unknown',
          topic: article[:topic] || article['topic'] || 'Other'
        }
      else
        {
          title: article.respond_to?(:title) ? article.title : 'Untitled',
          summary: article.respond_to?(:summary) ? article.summary : '',
          url: article.respond_to?(:url) ? article.url : '',
          published_at: article.respond_to?(:published_at) ? article.published_at : Time.current,
          source: article.respond_to?(:source) ? article.source : 'Unknown',
          topic: extract_topic(article)
        }
      end
      
      # Truncate summary to prevent large emails
      normalized[:summary] = normalized[:summary].to_s[0..500] + '...' if normalized[:summary].to_s.length > 500
      normalized
    end
  end
  
  # Memory-efficient topic grouping
  def create_topic_groups(articles)
    groups = {}
    
    articles.each do |article|
      topic = article[:topic] || 'Other'
      groups[topic] ||= []
      groups[topic] << article
    end
    
    # Sort articles within each topic by date
    groups.each do |topic, topic_articles|
      groups[topic] = topic_articles.sort_by { |a| a[:published_at] || Time.current }.reverse
    end
    
    groups
  end
  
  # Sort topics alphabetically with "Other" last
  def sort_topics(topic_keys)
    topic_keys.compact.sort do |a, b|
      if a == "Other"
        1
      elsif b == "Other"
        -1
      else
        a <=> b
      end
    end
  end
  
  # Extract topic from article object
  def extract_topic(article)
    if article.respond_to?(:news_source) && article.news_source&.topic
      article.news_source.topic.name
    else
      'Other'
    end
  end
  
  # Development-only logging to avoid memory overhead in production
  def log_article_distribution(articles)
    Rails.logger.info("\n=== Article Distribution in Email ===")
    topic_counts = articles.group_by { |a| a[:topic] }.transform_values(&:count)
    topic_counts.each do |topic, count|
      Rails.logger.info("#{topic}: #{count} articles")
    end
  end
  
  def get_memory_usage_mb
    rss_kb = `ps -o rss= -p #{Process.pid}`.to_i
    (rss_kb / 1024.0).round(2)
  rescue => e
    Rails.logger.error("[DailyNewsMailer] Memory monitoring error: #{e.message}")
    0.0
  end
end