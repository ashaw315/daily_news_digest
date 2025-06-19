class NewsSource < ApplicationRecord
  # Associations
  has_many :user_news_sources, dependent: :destroy
  has_many :users, through: :user_news_sources
  has_many :articles, dependent: :destroy
  belongs_to :topic, optional: true

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :url, presence: true  # Add URL validation if not already present
  validates :format, presence: true, inclusion: { in: ['rss'] }  # Simplified to only RSS
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :rss, -> { where(format: 'rss') }
  
  # Callbacks
  before_validation :set_format_to_rss, if: :new_record?

  def validate_source
    validator = SourceValidatorService.new(self)
    if validator.validate
      true
    else
      validator.errors
    end
  end

  def in_use?
    user_news_sources.exists? || articles.exists?
  end

  def article_count
    articles.count
  end

  def recent_articles(limit = 5)
    articles.recent.limit(limit)
  end

  private

  def set_format_to_rss
    self.format = 'rss'
  end
end