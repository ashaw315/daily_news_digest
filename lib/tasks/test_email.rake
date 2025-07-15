namespace :email do
  desc "Test email configuration and delivery"
  task test_config: :environment do
    puts "=== Email Configuration Test ==="
    puts "Rails environment: #{Rails.env}"
    puts "Delivery method: #{ActionMailer::Base.delivery_method}"
    puts "Perform deliveries: #{ActionMailer::Base.perform_deliveries}"
    puts "Raise delivery errors: #{ActionMailer::Base.raise_delivery_errors}"
    puts
    
    if ActionMailer::Base.delivery_method == :smtp
      puts "SMTP Configuration:"
      puts "  Address: #{ActionMailer::Base.smtp_settings[:address]}"
      puts "  Port: #{ActionMailer::Base.smtp_settings[:port]}"
      puts "  Domain: #{ActionMailer::Base.smtp_settings[:domain]}"
      puts "  User name: #{ActionMailer::Base.smtp_settings[:user_name]}"
      puts "  Password present: #{ActionMailer::Base.smtp_settings[:password].present?}"
      puts "  Authentication: #{ActionMailer::Base.smtp_settings[:authentication]}"
      puts "  STARTTLS: #{ActionMailer::Base.smtp_settings[:enable_starttls_auto]}"
      puts
      
      # Test environment variables
      puts "Environment Variables:"
      puts "  SENDGRID_API_KEY present: #{ENV['SENDGRID_API_KEY'].present?}"
      if ENV['SENDGRID_API_KEY'].present?
        api_key = ENV['SENDGRID_API_KEY']
        puts "  SENDGRID_API_KEY starts with: #{api_key[0..10]}..."
        puts "  SENDGRID_API_KEY length: #{api_key.length}"
      end
      puts
    end
    
    # Test basic email creation
    puts "=== Testing Email Creation ==="
    begin
      user = User.find_by(admin: true) || User.first
      if user
        puts "Testing with user: #{user.email}"
        
        # Create a simple test email
        mail = DailyNewsMailer.daily_digest(user, [])
        puts "✓ Email created successfully"
        puts "  Subject: #{mail.subject}"
        puts "  From: #{mail.from}"
        puts "  To: #{mail.to}"
        puts "  Content type: #{mail.content_type}"
        puts
        
        # Test email delivery
        puts "=== Testing Email Delivery ==="
        delivery_start = Time.current
        result = mail.deliver_now
        delivery_time = ((Time.current - delivery_start) * 1000).round(2)
        
        puts "✓ Email delivered successfully!"
        puts "  Delivery time: #{delivery_time}ms"
        puts "  Delivery result: #{result.inspect}"
        
      else
        puts "✗ No users found in database"
      end
    rescue => e
      puts "✗ Email test failed: #{e.class} - #{e.message}"
      puts "  Backtrace:"
      e.backtrace.first(5).each { |line| puts "    #{line}" }
    end
    
    puts "\n=== Test Complete ==="
  end
  
  desc "Send a simple test email using ActionMailer directly"
  task simple_test: :environment do
    puts "=== Simple Email Test ==="
    
    begin
      # Create a minimal test mailer
      test_mailer = Class.new(ActionMailer::Base) do
        default from: 'news@dailynewsdigest.com'
        
        def test_email(to_email)
          mail(
            to: to_email,
            subject: 'Test Email - Daily News Digest',
            body: 'This is a test email to verify SMTP configuration works correctly.'
          )
        end
      end
      
      # Send test email
      admin_user = User.find_by(admin: true)
      if admin_user
        puts "Sending test email to: #{admin_user.email}"
        
        mail = test_mailer.new.test_email(admin_user.email)
        result = mail.deliver_now
        
        puts "✓ Test email sent successfully!"
        puts "  Result: #{result.inspect}"
      else
        puts "✗ No admin user found"
      end
      
    rescue => e
      puts "✗ Simple email test failed: #{e.class} - #{e.message}"
      puts "  Backtrace:"
      e.backtrace.first(5).each { |line| puts "    #{line}" }
    end
  end
end