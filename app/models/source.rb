class Source < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :url, presence: true
  validates :source_type, presence: true, inclusion: { in: ['rss', 'api', 'scrape'] }
  
  serialize :selectors, coder: JSON
  
  scope :active, -> { where(active: true) }
  
  def self.source_types
    [
      ['RSS Feed', 'rss'],
      ['API', 'api'],
      ['Web Scraping', 'scrape']
    ]
  end
  
  def to_news_fetcher_source
    {
      name: name,
      type: source_type.to_sym,
      url: url,
      selectors: selectors
    }
  end
end