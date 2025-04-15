class Article < ApplicationRecord
  belongs_to :news_source  # Add this association

  validates :title, presence: true
  validates :url, presence: true, uniqueness: true
  validates :publish_date, presence: true
  validates :news_source, presence: true  # Add this validation
  
  # Update scopes to use news_source association
  scope :by_topic, ->(topic) { where(topic: topic) }
  scope :by_source, ->(news_source) { where(news_source: news_source) }
  scope :recent, -> { order(publish_date: :desc) }
  
  # Get related articles based on topic
  def related_articles(limit = 5)
    Article.by_topic(topic)
           .where.not(id: id)
           .recent
           .limit(limit)
  end
  
  # Extract keywords from the article content
  def keywords(count = 5)
    text = "#{title} #{summary}"
    
    # Remove stopwords
    stopwords = StopwordsFilter::Filter.new(:en)
    words = text.downcase.gsub(/[^\w\s]/, '').split
    filtered_words = words.reject { |word| stopwords.stopword?(word) }
    
    # Count word frequencies
    word_counts = Hash.new(0)
    filtered_words.each { |word| word_counts[word] += 1 }
    
    # Return top keywords
    word_counts.sort_by { |_, count| -count }.take(count).map(&:first)
  end

  # Add helper methods for source
  def source_name
    news_source&.name
  end

  def source_url
    news_source&.url
  end
end