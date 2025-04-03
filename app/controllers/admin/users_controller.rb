class Admin::UsersController < Admin::BaseController
  def index
    @users = User.all.order(created_at: :desc)
  end

  def show
    @user = User.find(params[:id])
    @topics = @user.topics
    @news_sources = @user.news_sources
    @email_metrics = @user.email_metrics.order(sent_at: :desc).limit(10)
  end
end