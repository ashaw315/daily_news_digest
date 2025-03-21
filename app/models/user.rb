class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
  :recoverable, :rememberable, :validatable,
  :confirmable

  has_one :email_tracking, dependent: :destroy
  
  validates :email, presence: true, uniqueness: true
  validates :preferences, presence: true, if: :preferences_required?
  
  # Define allowed preferences keys
  VALID_PREFERENCES = {
    'topics' => ['technology', 'science', 'business', 'health', 'sports'],
    'sources' => ['news_api', 'reuters', 'associated_press'],
    'frequency' => ['daily', 'weekly']
  }.freeze
  
  before_create :generate_unsubscribe_token
  
  def preferences=(value)
    value ||= {}
    super(value.slice(*VALID_PREFERENCES.keys))
  end

  def selected_topics
    (preferences&.dig('topics') || []).map(&:downcase)
  end

  def selected_sources
    (preferences&.dig('sources') || []).map(&:downcase)
  end

  def email_frequency
    preferences&.dig('frequency') || 'daily'
  end

  def reset_preferences!
    update!(preferences: {
      'topics' => [],
      'sources' => [],
      'frequency' => 'daily'
    })
  end

  def preferences_required?
    # Check if the user is being updated (not during sign-up)
    persisted? && (preferences['topics'].blank? || preferences['sources'].blank?)
  end

  def preferred_news_source
    # Use the first source in the sources array as the preferred source
    sources = preferences&.dig('sources')
    sources&.first
  end

  private
  
  def generate_unsubscribe_token
    self.unsubscribe_token = SecureRandom.urlsafe_base64(32)
  end
end
