class UserNewsSource < ApplicationRecord
    belongs_to :user
    belongs_to :news_source
    
    # Add validation to prevent duplicate associations
    validates :user_id, uniqueness: { scope: :news_source_id }
    
    # Automatically update user subscription status when associations change
    after_create :update_user_subscription_status
    after_destroy :update_user_subscription_status
    
    private
    
    def update_user_subscription_status
      user.fix_subscription_status!
    end
  end