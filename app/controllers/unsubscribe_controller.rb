class UnsubscribeController < ActionController::Base
  layout 'application'
  
  def process_unsubscribe
    user = User.find_by(unsubscribe_token: params[:token])
    
    if user
      user.update(is_subscribed: false)
      flash[:notice] = "You have been successfully unsubscribed from our emails."
    else
      flash[:alert] = "Invalid unsubscribe token."
    end
    
    # Redirect to the public home page
    redirect_to root_path
  end
end 