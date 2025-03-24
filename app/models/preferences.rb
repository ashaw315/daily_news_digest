class Preferences < ApplicationRecord
    belongs_to :user
    
    # Fix the deprecation warnings by using the new syntax
    serialize :topics, type: Array, coder: JSON
    serialize :sources, type: Array, coder: JSON
    
    # Define valid options
    VALID_TOPICS = ['technology', 'science', 'business', 'health', 'sports'].freeze
    VALID_SOURCES = ['news_api', 'reuters', 'associated_press'].freeze
    VALID_FREQUENCIES = ['daily', 'weekly'].freeze
    
    # Validations
    validate :validate_topics
    validate :validate_sources
    validates :email_frequency, inclusion: { in: VALID_FREQUENCIES }
    
    private
    
    def validate_topics
      return if topics.blank?
      invalid_topics = topics - VALID_TOPICS
      errors.add(:topics, "contains invalid topics: #{invalid_topics.join(', ')}") if invalid_topics.any?
    end
    
    def validate_sources
      return if sources.blank?
      invalid_sources = sources - VALID_SOURCES
      errors.add(:sources, "contains invalid sources: #{invalid_sources.join(', ')}") if invalid_sources.any?
    end
  end