class UserNewsSource < ApplicationRecord
    belongs_to :user
    belongs_to :news_source
    
    # Add validation to prevent duplicate associations
    validates :user_id, uniqueness: { scope: :news_source_id }
  end