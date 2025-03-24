class Admin::UsersController < Admin::BaseController
  def index
    @users = User.all
  end
  
  def show
    @user = User.find(params[:id])
    @preferences = @user.preferences || @user.build_preferences
  end
end 