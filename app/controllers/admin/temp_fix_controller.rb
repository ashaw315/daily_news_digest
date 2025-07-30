class Admin::TempFixController < Admin::BaseController
  # Temporary controller for one-time subscription fixes
  # Remove this file after fixing production data
  
  def fix_subscriptions
    results = []
    
    User.includes(:user_news_sources, :preferences).find_each do |user|
      old_status = user.is_subscribed?
      new_status = user.fix_subscription_status!
      
      if old_status != new_status
        results << {
          id: user.id,
          email: user.email,
          old_status: old_status,
          new_status: new_status,
          sources_count: user.user_news_sources.count,
          has_preferences: user.preferences.present?
        }
      end
    end
    
    render json: {
      status: 'success',
      message: "Fixed #{results.length} users",
      fixed_users: results,
      timestamp: Time.current.iso8601
    }
  end
  
  def fix_single_user
    email = params[:email] || 'ashaw315@gmail.com'
    user = User.find_by(email: email)
    
    if user.nil?
      render json: { status: 'error', message: "User #{email} not found" }
      return
    end
    
    old_status = user.is_subscribed?
    new_status = user.fix_subscription_status!
    
    render json: {
      status: 'success',
      user: {
        id: user.id,
        email: user.email,
        old_subscription_status: old_status,
        new_subscription_status: new_status,
        sources_count: user.user_news_sources.count,
        topics_count: user.user_topics.count,
        has_preferences: user.preferences.present?,
        should_be_subscribed: user.should_be_subscribed?
      },
      timestamp: Time.current.iso8601
    }
  end
end