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
    
    # Common English stopwords
    stopwords = %w(a about above after again against all am an and any are aren't as at be because been before being 
                  below between both but by can't cannot could couldn't did didn't do does doesn't doing don't down 
                  during each few for from further had hadn't has hasn't have haven't having he he'd he'll he's her 
                  here here's hers herself him himself his how how's i i'd i'll i'm i've if in into is isn't it it's 
                  its itself let's me more most mustn't my myself no nor not of off on once only or other ought our 
                  ours ourselves out over own same shan't she she'd she'll she's should shouldn't so some such than 
                  that that's the their theirs them themselves then there there's these they they'd they'll they're 
                  they've this those through to too under until up very was wasn't we we'd we'll we're we've were 
                  weren't what what's when when's where where's which while who who's whom why why's with won't 
                  would wouldn't you you'd you'll you're you've your yours yourself yourselves)
    
    # Remove special characters and split into words
    words = text.downcase.gsub(/[^\w\s]/, '').split
    
    # Filter out stopwords and short words
    filtered_words = words.reject { |word| stopwords.include?(word) || word.length <= 2 }
    
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