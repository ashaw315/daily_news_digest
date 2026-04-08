class Preferences < ApplicationRecord
  belongs_to :user
  
  # We no longer need to serialize topics since they're now in the user_topics join table
  # We'll keep sources serialized for now, but you might want to create a Source model later
  serialize :sources, type: Array, coder: JSON
  
  # Define valid options
  VALID_FREQUENCIES = ['daily'].freeze
  
  # Validations
  validates :email_frequency, inclusion: { in: VALID_FREQUENCIES }
  
  # We no longer need the validate_topics method since topics are now managed through the Topic model
  
end