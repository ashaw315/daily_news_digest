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
    begin
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
      
      # Get exactly 3 articles per source for email
      articles = []
      sources.each do |source|
        source_articles = Article.where(news_source: source)
                                .order(publish_date: :desc)
                                .limit(3)
        articles.concat(source_articles)
        Rails.logger.info("[ADMIN] Found #{source_articles.count} articles from #{source.name}")
      end
      Rails.logger.info("[ADMIN] Total articles for email: #{articles.count} from #{sources.count} sources")
      
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
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error("[ADMIN] User not found: #{e.message}")
      redirect_to admin_users_path, alert: "User not found"
    rescue => e
      Rails.logger.error("[ADMIN] Email delivery failed: #{e.class} - #{e.message}")
      Rails.logger.error("[ADMIN] Backtrace: #{e.backtrace.first(5).join(' | ')}")
      # Only redirect to user page if user was found
      if defined?(user) && user
        redirect_to admin_user_path(user), alert: "Failed to send test email: #{e.message}"
      else
        redirect_to admin_users_path, alert: "Failed to send test email: #{e.message}"
      end
    end
  end
  
  def send_simple_test_email
    user = User.find(params[:id])
    Rails.logger.info("[ADMIN] Sending simple test email via SendGrid API")
    
    begin
      # Use SendGrid API directly instead of SMTP
      require 'net/http'
      require 'json'
      
      if ENV['SENDGRID_API_KEY'].blank?
        raise "SendGrid API key not configured"
      end
      
      # Create simple email payload
      email_data = {
        personalizations: [{
          to: [{ email: user.email }],
          subject: "Simple Test Email - #{Time.current.strftime('%B %d, %Y at %I:%M %p')}"
        }],
        from: { email: ENV['EMAIL_FROM_ADDRESS'] || 'ashaw315@gmail.com' },
        content: [{
          type: 'text/html',
          value: <<~HTML
            <html>
              <body>
                <h1>Test Email</h1>
                <p>This is a simple test email sent directly via SendGrid API at #{Time.current}.</p>
                <p>If you receive this, your SendGrid integration is working correctly!</p>
              </body>
            </html>
          HTML
        }]
      }
      
      # Send via SendGrid API
      uri = URI('https://api.sendgrid.com/v3/mail/send')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{ENV['SENDGRID_API_KEY']}"
      request['Content-Type'] = 'application/json'
      request.body = email_data.to_json
      
      response = http.request(request)
      
      Rails.logger.info("[ADMIN] SendGrid API response: #{response.code} - #{response.body}")
      
      if response.code == '202'
        Rails.logger.info("[ADMIN] Simple test email sent successfully via API")
        redirect_to admin_user_path(user), notice: "Simple test email sent successfully via SendGrid API to #{user.email}"
      else
        Rails.logger.error("[ADMIN] SendGrid API error: #{response.code} - #{response.body}")
        redirect_to admin_user_path(user), alert: "SendGrid API error: #{response.code} - #{response.body}"
      end
      
    rescue => e
      Rails.logger.error("[ADMIN] Simple test email failed: #{e.class} - #{e.message}")
      redirect_to admin_user_path(user), alert: "Failed to send simple test email: #{e.message}"
    end
  end

  private
  
  def set_user
    @user = User.find(params[:id])
  end
end