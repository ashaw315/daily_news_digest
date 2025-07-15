class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [:show, :destroy]
  
  def index
    # Add pagination to prevent memory issues with kaminari
    @users = User.includes(:preferences).page(params[:page]).per(25)
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
    Rails.logger.info("[ADMIN] Starting test email for user: #{user.email}")
    
    # Log email configuration
    Rails.logger.info("[ADMIN] Email delivery method: #{ActionMailer::Base.delivery_method}")
    Rails.logger.info("[ADMIN] Perform deliveries: #{ActionMailer::Base.perform_deliveries}")
    Rails.logger.info("[ADMIN] Raise delivery errors: #{ActionMailer::Base.raise_delivery_errors}")
    
    if ActionMailer::Base.delivery_method == :smtp
      Rails.logger.info("[ADMIN] SMTP settings: #{ActionMailer::Base.smtp_settings.inspect}")
      Rails.logger.info("[ADMIN] SendGrid API key present: #{ENV['SENDGRID_API_KEY'].present?}")
    end
    
    sources = user.news_sources
    Rails.logger.info("[ADMIN] User has #{sources.count} subscribed news sources")
    
    # Fetch latest articles
    fetcher = EnhancedNewsFetcher.new(sources: sources, max_articles: 3)
    Rails.logger.info("[ADMIN] Fetching articles from sources...")
    fetcher.fetch_articles
    
    # Get articles for email
    articles = Article.where(news_source: sources).order(publish_date: :desc).limit(20)
    Rails.logger.info("[ADMIN] Found #{articles.count} articles for email")
    
    # Create and send email
    Rails.logger.info("[ADMIN] Creating email with DailyNewsMailer...")
    mail = DailyNewsMailer.daily_digest(user, articles)
    Rails.logger.info("[ADMIN] Email created, attempting delivery...")
    Rails.logger.info("[ADMIN] Email FROM address: #{mail.from}")
    Rails.logger.info("[ADMIN] Email TO address: #{mail.to}")
    Rails.logger.info("[ADMIN] Email subject: #{mail.subject}")
    
    # Try to deliver and log the result
    delivery_result = mail.deliver_now
    Rails.logger.info("[ADMIN] Email delivery result: #{delivery_result.inspect}")
    Rails.logger.info("[ADMIN] Email successfully sent to #{user.email}")
    
    redirect_to admin_user_path(user), notice: "Test email sent successfully to #{user.email}"
  rescue => e
    Rails.logger.error("[ADMIN] Email delivery failed: #{e.class} - #{e.message}")
    Rails.logger.error("[ADMIN] Backtrace: #{e.backtrace.first(5).join(' | ')}")
    redirect_to admin_user_path(user), alert: "Failed to send test email: #{e.message}"
  end

  private
  
  def set_user
    @user = User.find(params[:id])
  end
end