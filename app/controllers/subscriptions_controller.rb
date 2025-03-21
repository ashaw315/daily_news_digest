class SubscriptionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:unsubscribe]
  
  def unsubscribe
    user = User.find_by(unsubscribe_token: params[:token])
    
    if user
      # Automatically sign in the user
      sign_in(user)
      
      # Update subscription status
      user.update(is_subscribed: false)
      flash[:notice] = "You have been successfully unsubscribed from our emails."
    else
      flash[:alert] = "Invalid unsubscribe token."
    end
    
    # Redirect to root path
    redirect_to root_path
  end
end 