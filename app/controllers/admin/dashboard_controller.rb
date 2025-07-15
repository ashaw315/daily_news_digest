class Admin::DashboardController < Admin::BaseController
  def index
    @user_count = User.count
    @article_count = Article.count
    @source_count = NewsSource.count
    @email_metrics = {
      sent: EmailMetric.where(status: 'sent').count,
      opened: EmailMetric.where(status: 'opened').count,
      clicked: EmailMetric.where(status: 'clicked').count,
      failed: EmailMetric.where(status: 'failed').count
    }
  end
  
  def email_debug
    Rails.logger.info("[EMAIL_DEBUG] Starting email configuration debug")
    
    @email_config = {
      environment: Rails.env,
      delivery_method: ActionMailer::Base.delivery_method,
      perform_deliveries: ActionMailer::Base.perform_deliveries,
      raise_delivery_errors: ActionMailer::Base.raise_delivery_errors
    }
    
    if ActionMailer::Base.delivery_method == :smtp
      @smtp_config = {
        address: ActionMailer::Base.smtp_settings[:address],
        port: ActionMailer::Base.smtp_settings[:port],
        domain: ActionMailer::Base.smtp_settings[:domain],
        user_name: ActionMailer::Base.smtp_settings[:user_name],
        password_present: ActionMailer::Base.smtp_settings[:password].present?,
        authentication: ActionMailer::Base.smtp_settings[:authentication],
        starttls: ActionMailer::Base.smtp_settings[:enable_starttls_auto]
      }
    end
    
    @env_vars = {
      sendgrid_api_key_present: ENV['SENDGRID_API_KEY'].present?,
      sendgrid_api_key_length: ENV['SENDGRID_API_KEY']&.length,
      sendgrid_api_key_prefix: ENV['SENDGRID_API_KEY']&.slice(0, 10)
    }
    
    # Test email creation
    begin
      admin_user = User.find_by(admin: true)
      if admin_user
        Rails.logger.info("[EMAIL_DEBUG] Testing email creation for #{admin_user.email}")
        test_mail = DailyNewsMailer.daily_digest(admin_user, [])
        @test_email_result = {
          success: true,
          subject: test_mail.subject,
          from: test_mail.from,
          to: test_mail.to,
          content_type: test_mail.content_type
        }
        Rails.logger.info("[EMAIL_DEBUG] Email creation successful")
      else
        @test_email_result = { success: false, error: "No admin user found" }
      end
    rescue => e
      Rails.logger.error("[EMAIL_DEBUG] Email creation failed: #{e.message}")
      @test_email_result = { success: false, error: e.message, backtrace: e.backtrace.first(3) }
    end
    
    Rails.logger.info("[EMAIL_DEBUG] Email debug complete")
  end
end 