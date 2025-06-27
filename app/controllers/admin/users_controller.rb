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
  
  def send_test_email
    user = User.find(params[:id])
    sources = user.news_sources
    fetcher = EnhancedNewsFetcher.new(sources: sources)
    fetcher.fetch_articles # Fetch and save the latest articles
  
    articles = Article.where(news_source: sources).order(publish_date: :desc).limit(20)
    DailyNewsMailer.daily_digest(user, articles).deliver_now
    redirect_to admin_user_path(user), notice: "Test email sent to #{user.email}."
  rescue => e
    redirect_to admin_user_path(user), alert: "Failed to send test email: #{e.message}"
  end

  private
  
  def set_user
    @user = User.find(params[:id])
  end
end