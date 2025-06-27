module MailerHelper
  def topic_icon(topic)
    case topic.to_s.downcase
    when 'technology'
      '💻'
    when 'science'
      '🔬'
    when 'health'
      '🏥'
    when 'sports'
      '🏆'
    when 'business'
      '💼'
    when 'entertainment'
      '🎬'
    when 'politics'
      '🏛️'
    when 'world'
      '🌎'
    else
      '📰'
    end
  end

  def article_date(article)
    date = if article.respond_to?(:publish_date) && article.publish_date.present?
      article.publish_date
    elsif article.is_a?(Hash)
      article[:publish_date].presence || article[:published_at]
    end

    date&.strftime('%b %d, %Y') || Time.current.strftime('%b %d, %Y')
  end

  def article_source(article)
    # Prioritize the source column as it's explicitly set in the fetcher
    if article.respond_to?(:source) && article.source.present?
      article.source
    elsif article.respond_to?(:news_source) && article.news_source&.name.present?
      article.news_source.name
    elsif article.is_a?(Hash)
      article[:source].presence || article[:news_source]&.name
    else
      "Unknown Source"
    end
  end

  def article_summary(article)
    # Get the full AI-generated summary
    summary = if article.respond_to?(:summary) && article.summary.present?
      article.summary
    elsif article.respond_to?(:description) && article.description.present?
      article.description
    elsif article.is_a?(Hash)
      article[:summary].presence || article[:description]
    end

    return "No summary available" if summary.blank?
    
    # Clean up any double spaces or weird formatting
    summary = summary.strip.gsub(/\s+/, ' ')
    
    # Ensure we have complete sentences
    sentences = summary.split(/(?<=[.!?])\s+/)
    
    # If we only have one sentence, return it
    return summary if sentences.length == 1
    
    # Otherwise, ensure we end with a complete sentence
    complete_sentences = sentences.each_with_object([]) do |sentence, acc|
      # Stop if we're getting too long
      break acc if acc.join(' ').length > 500
      acc << sentence
    end
    
    complete_sentences.join(' ').strip
  end

  def format_article_for_text(article)
    [
      article.title,
      article_summary(article),
      "#{article_source(article)} | #{article_date(article)}",
      "Read More"
    ].join("\n")
  end

  def format_article_for_html(article)
    content_tag(:div, class: 'article') do
      concat content_tag(:h3, article.title, class: 'article-title')
      concat content_tag(:div, article_summary(article), class: 'article-summary')
      concat content_tag(:div, class: 'article-meta') do
        "#{article_source(article)} | #{article_date(article)}"
      end
      concat link_to('Read More', article.url, class: 'read-more')
    end
  end

  def group_articles_by_topic(articles)
    articles.group_by { |article| article.topic || "Other" }
  end

  def sort_topics(topics)
    # Custom sort order for topics
    topic_order = %w[world politics business technology science health sports entertainment]
    
    topics.sort_by do |topic|
      idx = topic_order.index(topic.to_s.downcase)
      idx ? idx : topic_order.length
    end
  end
end