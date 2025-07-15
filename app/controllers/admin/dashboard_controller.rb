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
      sendgrid_api_key_prefix: ENV['SENDGRID_API_KEY']&.slice(0, 10),
      email_from_address: ENV['EMAIL_FROM_ADDRESS'] || "ashaw315@gmail.com"
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
  
  def check_sendgrid_status
    Rails.logger.info("[SENDGRID] Checking SendGrid API status")
    
    if ENV['SENDGRID_API_KEY'].blank?
      @sendgrid_status = { error: "SendGrid API key not configured" }
      return
    end
    
    begin
      # Simple API test to verify SendGrid connectivity
      require 'net/http'
      require 'json'
      
      uri = URI('https://api.sendgrid.com/v3/user/profile')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{ENV['SENDGRID_API_KEY']}"
      request['Content-Type'] = 'application/json'
      
      response = http.request(request)
      
      if response.code == '200'
        profile_data = JSON.parse(response.body)
        @sendgrid_status = {
          success: true,
          email: profile_data['email'],
          username: profile_data['username'],
          response_code: response.code
        }
        Rails.logger.info("[SENDGRID] API check successful")
      else
        @sendgrid_status = {
          success: false,
          error: "API returned #{response.code}: #{response.body}",
          response_code: response.code
        }
        Rails.logger.error("[SENDGRID] API check failed: #{response.code}")
      end
      
    rescue => e
      Rails.logger.error("[SENDGRID] API check error: #{e.message}")
      @sendgrid_status = {
        success: false,
        error: e.message,
        error_class: e.class.name
      }
    end
    
    respond_to do |format|
      format.html { render json: @sendgrid_status }
      format.json { render json: @sendgrid_status }
    end
  end
  
  def email_test_suite
    @user = User.find_by(admin: true) || User.first
    @test_results = []
    
    Rails.logger.info("[EMAIL_TEST] Starting comprehensive email test suite")
    
    # Test 1: Check SendGrid API connectivity
    Rails.logger.info("[EMAIL_TEST] Test 1: SendGrid API connectivity")
    sendgrid_test = test_sendgrid_api
    @test_results << {
      test: "SendGrid API Connectivity",
      status: sendgrid_test[:success] ? "✅ PASS" : "❌ FAIL",
      details: sendgrid_test
    }
    
    # Test 2: Send simple email via SendGrid API
    if @user && sendgrid_test[:success]
      Rails.logger.info("[EMAIL_TEST] Test 2: Direct SendGrid API email")
      api_email_test = send_test_email_via_api(@user)
      @test_results << {
        test: "SendGrid API Email",
        status: api_email_test[:success] ? "✅ PASS" : "❌ FAIL", 
        details: api_email_test
      }
    end
    
    # Test 3: Send email via Rails ActionMailer
    if @user
      Rails.logger.info("[EMAIL_TEST] Test 3: Rails ActionMailer email")
      actionmailer_test = send_test_email_via_actionmailer(@user)
      @test_results << {
        test: "Rails ActionMailer Email",
        status: actionmailer_test[:success] ? "✅ PASS" : "❌ FAIL",
        details: actionmailer_test
      }
    end
    
    Rails.logger.info("[EMAIL_TEST] Test suite completed")
  end
  
  private
  
  def test_sendgrid_api
    return { success: false, error: "SendGrid API key not configured" } if ENV['SENDGRID_API_KEY'].blank?
    
    begin
      require 'net/http'
      require 'json'
      
      uri = URI('https://api.sendgrid.com/v3/user/profile')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{ENV['SENDGRID_API_KEY']}"
      request['Content-Type'] = 'application/json'
      
      response = http.request(request)
      
      if response.code == '200'
        profile_data = JSON.parse(response.body)
        { success: true, email: profile_data['email'], username: profile_data['username'] }
      else
        { success: false, error: "API returned #{response.code}: #{response.body}" }
      end
    rescue => e
      { success: false, error: e.message }
    end
  end
  
  def send_test_email_via_api(user)
    begin
      require 'net/http'
      require 'json'
      
      email_data = {
        personalizations: [{
          to: [{ email: user.email }],
          subject: "Test Email via SendGrid API - #{Time.current.strftime('%I:%M:%S %p')}"
        }],
        from: { email: ENV['EMAIL_FROM_ADDRESS'] || 'ashaw315@gmail.com' },
        content: [{
          type: 'text/html',
          value: <<~HTML
            <html>
              <body>
                <h2>✅ SendGrid API Test Email</h2>
                <p><strong>Sent at:</strong> #{Time.current}</p>
                <p><strong>Method:</strong> Direct SendGrid API call</p>
                <p><strong>Status:</strong> If you see this, the SendGrid API is working!</p>
              </body>
            </html>
          HTML
        }]
      }
      
      uri = URI('https://api.sendgrid.com/v3/mail/send')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{ENV['SENDGRID_API_KEY']}"
      request['Content-Type'] = 'application/json'
      request.body = email_data.to_json
      
      response = http.request(request)
      
      if response.code == '202'
        { success: true, message: "Email sent successfully", response_code: response.code }
      else
        { success: false, error: "SendGrid API error: #{response.code} - #{response.body}" }
      end
    rescue => e
      { success: false, error: e.message }
    end
  end
  
  def send_test_email_via_actionmailer(user)
    begin
      # Use the same logic as the daily email job for consistency
      articles = ArticleFetcher.fetch_for_user(user)
      
      # Create daily digest email
      mail = DailyNewsMailer.daily_digest(user, articles)
      result = mail.deliver_now
      
      { success: true, message: "Daily digest email sent via ActionMailer", result: result.class.name, articles_count: articles.size }
    rescue => e
      { success: false, error: e.message }
    end
  end
end 