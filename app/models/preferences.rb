class Preferences < ApplicationRecord
  belongs_to :user
  
  # We no longer need to serialize topics since they're now in the user_topics join table
  # We'll keep sources serialized for now, but you might want to create a Source model later
  serialize :sources, type: Array, coder: JSON
  
  # Define valid options
  VALID_FREQUENCIES = ['daily', 'weekly'].freeze
  
  # Validations
  validates :email_frequency, inclusion: { in: VALID_FREQUENCIES }
  
  # We no longer need the validate_topics method since topics are now managed through the Topic model
  
  def validate_sources
    return if sources.blank?
    valid_sources = Source.active.pluck(:name)
    invalid_sources = sources - valid_sources
    errors.add(:sources, "contains invalid sources: #{invalid_sources.join(', ')}") if invalid_sources.any?
  end
end