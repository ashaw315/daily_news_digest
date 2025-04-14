class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [:show, :destroy]
  
  def index
    @users = User.all
  end
  
  def show
    # No need for any code here, @user is set by before_action
    @topics = @user.topics
    @news_sources = @user.news_sources
    @email_metrics = @user.email_metrics.order(sent_at: :desc).limit(10)
  end
  
  def destroy
    @user.destroy
    redirect_to admin_users_path, notice: "User was successfully deleted."
  end
  
  private
  
  def set_user
    @user = User.find(params[:id])
  end
end