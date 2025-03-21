class PublicController < ActionController::Base
  # This controller inherits from ActionController::Base directly
  # so it doesn't inherit the authenticate_user! before_action
  
  layout 'application'
end 