namespace :cron_test do
    desc "Test fetch articles cron job"
task fetch_articles: :environment do
  puts "\n=== Testing Fetch Articles ==="
  puts "Environment: #{Rails.env}"
  puts "Time: #{Time.current}"
  
  begin
    # Get initial counts
    initial_article_count = Article.count
    active_sources = NewsSource.joins(:users)
                              .where(users: { is_subscribed: true })
                              .where(active: true)
                              .where.not(url: [nil, ''])
                              .distinct
    subscribed_users_count = User.joins(:news_sources)
                                .where(is_subscribed: true)
                                .where(news_sources: { id: active_sources.pluck(:id) })
                                .distinct
                                .count
    
    puts "\nPre-execution stats:"
    puts "- Subscribed users with news sources: #{subscribed_users_count}"
    puts "- Active sources with subscribed users: #{active_sources.count}"
    puts "- Current article count: #{initial_article_count}"
    
    # Verify news sources have valid URLs
    active_sources.each do |source|
      puts "\nChecking source: #{source.name}"
      puts "- URL: #{source.url}"
      if source.url.blank?
        puts "❌ ERROR: Missing URL for source #{source.name}"
        next
      end
      
      begin
        uri = URI.parse(source.url)
        unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
          puts "❌ ERROR: Invalid URL format for source #{source.name}"
        end
      rescue URI::InvalidURIError => e
        puts "❌ ERROR: Invalid URL for source #{source.name}: #{e.message}"
      end
    end

    if active_sources.none? { |s| s.url.present? }
      puts "\n❌ ERROR: No sources have valid URLs. Please fix source URLs before testing."
      exit 1
    end
    
    # Execute the controller action with proper setup
    controller = Admin::CronController.new
    env = Rack::MockRequest.env_for('/')
    request = ActionDispatch::Request.new(env)
    request.headers['X-API-KEY'] = ENV['CRON_API_KEY']
    
    controller.instance_variable_set('@_request', request)
    controller.instance_variable_set('@_response', ActionDispatch::Response.new)
    
    # Call the action
    controller.fetch_articles
    
    # Get final counts
    final_article_count = Article.count
    new_articles = final_article_count - initial_article_count
    
    puts "\nPost-execution stats:"
    puts "- New articles created: #{new_articles}"
    puts "- Final article count: #{final_article_count}"
    
    # Validate results
    if new_articles == 0
      puts "\n⚠️  WARNING: No new articles were created"
      puts "Please check:"
      puts "1. News source URLs are valid RSS feeds"
      puts "2. Feeds contain recent articles"
      puts "3. No network connectivity issues"
      
      # Show last fetch status for each source
      puts "\nSource fetch status:"
      active_sources.each do |source|
        puts "#{source.name}:"
        puts "- Last fetch status: #{source.last_fetch_status}"
        puts "- Last fetched at: #{source.last_fetched_at}"
        puts "- Last article count: #{source.last_fetch_article_count}"
      end
    end
    
    puts "\n=== Test Completed ==="
    puts new_articles > 0 ? "✅ SUCCESS: Articles were fetched" : "⚠️  WARNING: No articles fetched"
    
  rescue => e
    puts "\n❌ ERROR: Task failed"
    puts "Error message: #{e.message}"
    puts "Backtrace:"
    puts e.backtrace.first(5)
    puts "\n=== Test Failed ==="
    exit 1
  end
end
  
    desc "Test daily email scheduling"
    task schedule_daily_emails: :environment do
      puts "\n=== Testing Schedule Daily Emails ==="
      puts "Environment: #{Rails.env}"
      puts "Time: #{Time.current}"
      
      begin
        # Get initial counts
        subscribed_users = User.joins(:preferences)
                              .where(is_subscribed: true)
                              .where('preferences.email_frequency = ?', 'daily')
        
        puts "\nPre-execution stats:"
        puts "- Subscribed users for daily emails: #{subscribed_users.count}"
        puts "- Active job queue adapter: #{Rails.application.config.active_job.queue_adapter}"
        
        # Execute the controller action
        controller = Admin::CronController.new
        # Create a test request
        env = Rack::MockRequest.env_for('/')
        request = ActionDispatch::Request.new(env)
        request.headers['X-API-KEY'] = ENV['CRON_API_KEY']
        
        # Assign the request to the controller
        controller.instance_variable_set('@_request', request)
        controller.instance_variable_set('@_response', ActionDispatch::Response.new)
        
        # Call the action
        controller.schedule_daily_emails
        
        puts "\nPost-execution stats:"
        puts "- Email scheduling task completed"
        puts "- Jobs processed with #{Rails.application.config.active_job.queue_adapter} adapter"
        
        puts "\n=== Test Completed Successfully ==="
      rescue => e
        puts "\nError running task: #{e.message}"
        puts "Backtrace:"
        puts e.backtrace.first(5)
        puts "\n=== Test Failed ==="
      end
    end
  
    desc "Test article purging"
    task purge_articles: :environment do
      puts "\n=== Testing Purge Articles ==="
      puts "Environment: #{Rails.env}"
      puts "Time: #{Time.current}"
      
      begin
        # Get initial counts
        initial_article_count = Article.count
        old_articles = Article.where("created_at < ?", 24.hours.ago).count
        
        puts "\nPre-execution stats:"
        puts "- Total articles: #{initial_article_count}"
        puts "- Articles older than 24 hours: #{old_articles}"
        
        # Execute the controller action
        controller = Admin::CronController.new
        # Create a test request
        env = Rack::MockRequest.env_for('/')
        request = ActionDispatch::Request.new(env)
        request.headers['X-API-KEY'] = ENV['CRON_API_KEY']
        
        # Assign the request to the controller
        controller.instance_variable_set('@_request', request)
        controller.instance_variable_set('@_response', ActionDispatch::Response.new)
        
        # Call the action
        controller.purge_articles
        
        # Get final counts
        final_article_count = Article.count
        deleted_articles = initial_article_count - final_article_count
        
        puts "\nPost-execution stats:"
        puts "- Articles deleted: #{deleted_articles}"
        puts "- Final article count: #{final_article_count}"
        
        puts "\n=== Test Completed Successfully ==="
      rescue => e
        puts "\nError running task: #{e.message}"
        puts "Backtrace:"
        puts e.backtrace.first(5)
        puts "\n=== Test Failed ==="
      end
    end
  
    desc "Test all cron jobs"
    task all: [:fetch_articles, :schedule_daily_emails, :purge_articles] do
      puts "\n=== All Cron Tests Completed ==="
    end
  end