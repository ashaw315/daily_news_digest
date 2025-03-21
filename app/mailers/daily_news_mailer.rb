class DailyNewsMailer < ApplicationMailer
  default from: "news@dailynewsdigest.com"
  #
  def daily_digest(user, articles)
    @user = user
    @articles = articles
    @preferences = user.preferences || {}
    @topics = @preferences['topics'] || []
    
    # Group articles by topic
    @articles_by_topic = @articles.group_by { |article| article.topic }
    
    # Get top 10 articles overall
    @top_articles = @articles.sort_by(&:published_at).reverse.first(10)
    
    # Brief news summaries (10-15 bullet points)
    @news_brief = @articles.sample(rand(10..15))
    
    mail(
      to: @user.email,
      subject: "Your Daily News Digest - #{Date.today.strftime('%B %d, %Y')}"
    )
  end

  def weekly_digest(user, articles)
    @user = user
    @articles = articles
    @preferences = user.preferences || {}
    @topics = @preferences['topics'] || []
    
    # Similar setup to daily_digest but with weekly framing
    @articles_by_topic = @articles.group_by { |article| article.topic }
    @top_articles = @articles.sort_by(&:published_at).reverse.first(10)
    @news_brief = @articles.sample(rand(10..15))
    
    mail(
      to: @user.email,
      subject: "Your Weekly News Digest - #{Date.today.strftime('%B %d, %Y')}"
    )
  end
end
