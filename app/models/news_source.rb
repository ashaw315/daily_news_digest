class NewsSource < ApplicationRecord
    validates :name, presence: true, uniqueness: true
    validates :format, presence: true, inclusion: { in: ['rss', 'api', 'web_scraped'] }

    has_many :user_news_sources, dependent: :destroy
    has_many :users, through: :user_news_sources
    
    scope :active, -> { where(active: true) }
    scope :rss, -> { where(format: 'rss') }
    scope :api, -> { where(format: 'api') }
    scope :web_scraped, -> { where(format: 'web_scraped') }
  end