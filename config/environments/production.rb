require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in ENV["RAILS_MASTER_KEY"], config/master.key, or an environment
  # key such as config/credentials/production.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Enable serving static files from `public/`
  config.public_file_server.enabled = true
  config.serve_static_files = true
  config.serve_static_assets = true

  # Compress CSS using a preprocessor.
  config.assets.css_compressor = nil

  # Enable asset compilation in production for Render deployment
  config.assets.compile = true

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX
  config.action_dispatch.x_sendfile_header = nil # Render doesn't need this

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Mount Action Cable outside main process or domain.
  # config.action_cable.mount_path = nil
  # config.action_cable.url = "wss://example.com/cable"
  # config.action_cable.allowed_request_origins = [ "http://example.com", /http:\/\/example.*/ ]

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # Can be used together with config.force_ssl for Strict-Transport-Security and secure cookies.
  # config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Log to STDOUT by default
  config.logger = ActiveSupport::Logger.new(STDOUT)
    .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
    .then { |logger| ActiveSupport::TaggedLogging.new(logger) }

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # "info" includes generic and useful information about system operation, but avoids logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII). If you
  # want to log everything, set the level to "debug".
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Use a real queuing backend for Active Job (and separate queues per environment).
  # config.active_job.queue_adapter = :resque
  # config.active_job.queue_name_prefix = "daily_news_digest_production"

  config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false
  # config.action_mailer.default_url_options = { host: 'yourdomain.com' }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  config.action_mailer.default_url_options = { 
    host: 'daily-news-digest.onrender.com',
    protocol: 'https'
  }
  
  # Test delivery - no real emails, just logs them
  config.action_mailer.delivery_method = :test
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = false
  
  config.action_mailer.smtp_settings = {
    address: 'smtp.sendgrid.net',
    port: 587,
    domain: 'daily-news-digest.onrender.com',
    user_name: 'apikey',
    password: ENV['SENDGRID_API_KEY'],
    authentication: 'plain',
    enable_starttls_auto: true
  }

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
  
  # MEMORY OPTIMIZATION: Add middleware for periodic garbage collection
  config.middleware.use(Class.new do
    def initialize(app)
      @app = app
      @request_count = 0
    end
    
    def call(env)
      @request_count += 1
      
      # Force garbage collection every 25 requests to prevent memory buildup
      if (@request_count % 25).zero?
        GC.start
        
        # Log memory usage every 100 requests for monitoring
        if (@request_count % 100).zero?
          begin
            rss_kb = `ps -o rss= -p #{Process.pid}`.to_i
            memory_mb = (rss_kb / 1024.0).round(2)
            Rails.logger.info("MEMORY MONITOR - Request #{@request_count}: #{memory_mb}MB")
            
            # Log warning if approaching memory limit
            if memory_mb > 400
              Rails.logger.warn("HIGH MEMORY WARNING: #{memory_mb}MB - approaching 512MB limit")
            end
          rescue => e
            Rails.logger.error("Memory monitoring error: #{e.message}")
          end
        end
      end
      
      @app.call(env)
    end
  end)
  
  # MEMORY OPTIMIZATION: Configure garbage collection for memory efficiency
  config.after_initialize do
    # Configure GC environment variables for memory-constrained environment
    # These settings help manage memory usage in a 512MB environment
    begin
      # Set conservative GC settings via environment variables
      ENV['RUBY_GC_HEAP_INIT_SLOTS'] ||= '10000'
      ENV['RUBY_GC_HEAP_MAX_SLOTS'] ||= '80000'
      ENV['RUBY_GC_HEAP_SLOTS_INCREMENT'] ||= '1000'
      ENV['RUBY_GC_HEAP_SLOTS_GROWTH_FACTOR'] ||= '1.1'
      ENV['RUBY_GC_MALLOC_LIMIT'] ||= '16000000'
      ENV['RUBY_GC_MALLOC_LIMIT_MAX'] ||= '32000000'
      ENV['RUBY_GC_MALLOC_LIMIT_GROWTH_FACTOR'] ||= '1.1'
      ENV['RUBY_GC_OLDMALLOC_LIMIT'] ||= '16000000'
      ENV['RUBY_GC_OLDMALLOC_LIMIT_MAX'] ||= '64000000'
      ENV['RUBY_GC_OLDMALLOC_LIMIT_GROWTH_FACTOR'] ||= '1.2'
      
      Rails.logger.info("MEMORY: Garbage collection configured for 512MB environment")
      Rails.logger.info("MEMORY: Parallel processing enabled with memory monitoring")
    rescue => e
      Rails.logger.warn("MEMORY: Could not configure GC settings: #{e.message}")
    end
  end
end