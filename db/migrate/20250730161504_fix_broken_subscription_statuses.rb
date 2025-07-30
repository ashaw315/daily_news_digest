class FixBrokenSubscriptionStatuses < ActiveRecord::Migration[7.1]
  def up
    # Fix subscription status for all users based on their current data
    say "Fixing subscription statuses for all users..."
    
    fixed_count = 0
    
    User.includes(:user_news_sources, :preferences).find_each do |user|
      old_status = user.is_subscribed?
      
      # Apply the same logic as should_be_subscribed?
      should_be_subscribed = user.user_news_sources.exists? && user.preferences.present?
      
      if old_status != should_be_subscribed
        user.update_column(:is_subscribed, should_be_subscribed)
        fixed_count += 1
        say "  Fixed user #{user.id} (#{user.email}): #{old_status} → #{should_be_subscribed}"
      end
    end
    
    say "Fixed #{fixed_count} users' subscription statuses"
    
    # Show final statistics
    total_users = User.count
    subscribed_users = User.where(is_subscribed: true).count
    users_with_sources = User.joins(:user_news_sources).distinct.count
    
    say "Final stats: #{subscribed_users}/#{total_users} users subscribed, #{users_with_sources} have sources"
  end

  def down
    # This migration cannot be easily reversed since we don't know the original incorrect state
    say "Cannot reverse this migration - subscription statuses were corrected"
  end
end
