class User < ApplicationRecord
  # Include default devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable

  has_one :email_tracking, dependent: :destroy
  has_one :preferences, dependent: :destroy
  has_many :email_metrics, dependent: :destroy
  
  validates :email, presence: true, uniqueness: true
  
  before_create :generate_unsubscribe_token
  after_create :create_default_preferences
  
  def admin?
    admin
  end
  
  def selected_topics
    preferences&.topics || []
  end

  def selected_sources
    preferences&.sources || []
  end

  def email_frequency
    preferences&.email_frequency || 'daily'
  end

  def reset_preferences!
    preferences.update!(
      topics: [],
      sources: [],
      email_frequency: 'daily'
    )
  end

  def preferred_news_source
    sources = preferences&.sources
    sources&.first
  end
  
  private
  
  def generate_unsubscribe_token
    self.unsubscribe_token = SecureRandom.urlsafe_base64(32)
  end

  def create_default_preferences
    create_preferences!(
      topics: [],
      sources: [],
      email_frequency: 'daily',
      dark_mode: false
    ) unless preferences
  end
end