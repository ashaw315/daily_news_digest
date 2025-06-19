class DailyNewsMailer < ApplicationMailer
  default from: "news@dailynewsdigest.com"

  def daily_digest(user, articles)
    @user = user
    @articles = articles

    # Group articles by topic for organization in the email
    @articles_by_topic = @articles.group_by { |article| article.topic || "Other" }

    # Optionally, sort topics alphabetically
    @sorted_topics = @articles_by_topic.keys.compact.sort

    # Optionally, sort articles within each topic by published date or rank
    @articles_by_topic.each do |topic, arts|
      @articles_by_topic[topic] = arts.sort_by { |a| a.try(:rank) || a.try(:published_at) || Time.zone.now }.reverse
    end

    mail(
      to: @user.email,
      subject: "Your Daily News Digest - #{Date.today.strftime('%B %d, %Y')}"
    )
  end

  def weekly_digest(user, articles)
    @user = user
    @articles = articles

    @articles_by_topic = @articles.group_by { |article| article.topic || "Other" }
    @sorted_topics = @articles_by_topic.keys.compact.sort

    @articles_by_topic.each do |topic, arts|
      @articles_by_topic[topic] = arts.sort_by { |a| a.try(:rank) || a.try(:published_at) || Time.zone.now }.reverse
    end

    mail(
      to: @user.email,
      subject: "Your Weekly News Digest - #{Date.today.strftime('%B %d, %Y')}"
    )
  end
end