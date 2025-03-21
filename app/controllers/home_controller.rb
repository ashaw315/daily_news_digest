class HomeController < ActionController::Base
  layout 'application'
  
  def index
    # This is a public landing page that doesn't require authentication
    render :index
  end
end
