class User < ApplicationRecord
  # Include default devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable

  has_one :email_tracking, dependent: :destroy
  has_one :preferences, dependent: :destroy
  has_many :email_metrics, dependent: :destroy
  
  has_many :user_topics, dependent: :destroy
  has_many :topics, through: :user_topics

  has_many :user_news_sources, dependent: :destroy
  has_many :news_sources, through: :user_news_sources
  
  validates :email, presence: true, uniqueness: true
  validate :news_source_limit
  validate :must_have_at_least_one_news_source
  
  before_create :generate_unsubscribe_token
  after_create :create_default_preferences

  # attribute :preferences, :jsonb, default: {}
  accepts_nested_attributes_for :preferences
  
  def admin?
    admin
  end
  
  def selected_topics
    topics.pluck(:name)
  end

  def selected_sources
    preferences&.sources || []
  end

  def email_frequency
    preferences&.email_frequency || 'daily'
  end

  def news_source_limit
    if news_source_ids.size > 15
      errors.add(:news_sources, "You can select up to 15 news sources")
    end
  end

  def reset_preferences!
    # Clear existing preferences
    user_topics.destroy_all
    user_news_sources.destroy_all
    
    # Reset preferences attributes
    preferences.update!(
      email_frequency: 'daily',
      dark_mode: false
    )
    
    # Create default topic and news source associations
    create_default_preferences
    
    # Return true to indicate success
    true
  rescue => e
    # Log the error
    Rails.logger.error "Error resetting preferences: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Return false to indicate failure
    false
  end

  def preferred_news_source
    sources = preferences&.sources
    sources&.first
  end

  def unsubscribe!
    self.update_columns(is_subscribed: false)
  end

  def subscribe!
    self.update_columns(is_subscribed: true)
  end

  def should_be_subscribed?
    # User should be subscribed if they have news sources and preferences set up
    user_news_sources.exists? && preferences.present?
  end

  def fix_subscription_status!
    # Fix subscription status based on user setup
    if should_be_subscribed? && !is_subscribed?
      Rails.logger.info "Setting user #{id} (#{email}) as subscribed - has #{user_news_sources.count} sources"
      update_column(:is_subscribed, true)
      true
    elsif !should_be_subscribed? && is_subscribed?
      Rails.logger.info "Setting user #{id} (#{email}) as unsubscribed - missing setup"
      update_column(:is_subscribed, false)
      false
    else
      is_subscribed?
    end
  end
  
  private
  
  def generate_unsubscribe_token
    self.unsubscribe_token = SecureRandom.urlsafe_base64(32)
  end

  def create_default_preferences
    Rails.logger.debug "Creating default preferences for user #{id}"
    
    # Get the first 3 active topics
    default_topics = Topic.active.limit(3)
    Rails.logger.debug "Default topics: #{default_topics.pluck(:name)}"
    
    # Get the first active news source
    default_source = NewsSource.active.first
    Rails.logger.debug "Default news source: #{default_source&.name}"
    
    # Associate the default topics with the user
    default_topics.each do |topic|
      user_topics.create!(topic: topic)
    end
    
    # Associate the default news source with the user
    user_news_sources.create!(news_source: default_source) if default_source
    
    # Create preferences with default values if they don't exist
    if preferences.nil?
      create_preferences!(
        email_frequency: 'daily',
        dark_mode: false
      )
    end
    
    # Set user as subscribed when they have preferences set up
    update_column(:is_subscribed, true) unless is_subscribed?
    
    Rails.logger.debug "Default preferences created successfully"
  rescue => e
    Rails.logger.error "Error creating default preferences: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  def must_have_at_least_one_news_source
    return if new_record? # Skip validation on user creation
    source_count = news_source_ids.reject(&:blank?).size
    if source_count < 1
      errors.add(:news_sources, "You must select at least 1 news source")
    end
  end

  # def minimum_preferences_selected
  #   # Skip validation for new records (during registration)
  #   return if new_record?
    
  #   topic_count = topics.size
  #   source_count = news_sources.size

  #    Rails.logger.debug "VALIDATION: User #{id} has #{topic_count} topics and #{source_count} news sources"
    
  #   if topic_count < 3
  #     errors.add(:topics, "You must select at least 3 topics (you selected #{topic_count})")
  #   end
    
  #   if source_count < 1
  #     errors.add(:news_sources, "You must select at least 1 news source")
  #   end
  # end
end