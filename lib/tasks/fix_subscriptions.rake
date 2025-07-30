namespace :subscriptions do
  desc "Fix subscription status for all users based on their news sources"
  task fix: :environment do
    puts "=== Fixing User Subscription Status ==="
    puts "Time: #{Time.current}"
    puts
    
    total_users = User.count
    fixed_count = 0
    
    puts "Checking #{total_users} users..."
    
    User.find_each do |user|
      old_status = user.is_subscribed?
      new_status = user.fix_subscription_status!
      
      if old_status != new_status
        puts "  User #{user.id} (#{user.email}): #{old_status} → #{new_status}"
        puts "    Sources: #{user.user_news_sources.count}"
        puts "    Has preferences: #{user.preferences.present?}"
        fixed_count += 1
      end
    end
    
    puts
    puts "Fixed #{fixed_count} users"
    
    # Show final statistics
    subscribed_count = User.where(is_subscribed: true).count
    users_with_sources_count = User.joins(:user_news_sources).distinct.count
    
    puts
    puts "Final Statistics:"
    puts "  Total users: #{total_users}"
    puts "  Subscribed users: #{subscribed_count}"
    puts "  Users with sources: #{users_with_sources_count}"
    
    puts
    puts "=== Subscription Fix Complete ==="
  end
  
  desc "Show current subscription status for all users"
  task status: :environment do
    puts "=== Current Subscription Status ==="
    puts "Time: #{Time.current}"
    puts
    
    User.includes(:user_news_sources, :preferences).each do |user|
      sources_count = user.user_news_sources.count
      has_prefs = user.preferences.present?
      is_subscribed = user.is_subscribed?
      should_be_subscribed = user.should_be_subscribed?
      
      status_indicator = is_subscribed == should_be_subscribed ? "✓" : "✗"
      
      puts "#{status_indicator} User #{user.id} (#{user.email}):"
      puts "    Admin: #{user.admin? || false}"
      puts "    is_subscribed: #{is_subscribed}"
      puts "    should_be_subscribed: #{should_be_subscribed}"
      puts "    Sources: #{sources_count}"
      puts "    Has preferences: #{has_prefs}"
      puts "    Status: #{is_subscribed == should_be_subscribed ? 'CORRECT' : 'NEEDS FIX'}"
      puts
    end
  end
end