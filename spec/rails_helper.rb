# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
require 'capybara/rspec'
require 'devise'
require 'database_cleaner/active_record'
require 'webmock/rspec'
require 'webdrivers'
# Webdrivers::Chromedriver.required_version = '137.0.7151.119'
Selenium::WebDriver::Chrome::Service.driver_path = "/usr/local/bin/chromedriver"

# Enable auto-loading of support files
Dir[Rails.root.join('spec/support/**/*.rb')].sort.each { |f| require f }

# Configure WebMock
WebMock.disable_net_connect!(
  allow_localhost: true,
  allow: [
    'chromedriver.storage.googleapis.com',
    'googlechromelabs.github.io',
    '127.0.0.1',
    'localhost'
  ]
)

# Configure Capybara
Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1400,1400')
  
  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    options: options
  )
end

Capybara.javascript_driver = :selenium_chrome_headless
Capybara.default_max_wait_time = 5

# Fix for transactional fixtures
class ActiveRecord::Base
  mattr_accessor :shared_connection
  @@shared_connection = nil

  def self.connection
    @@shared_connection || ConnectionPool::Wrapper.new(size: 1) { retrieve_connection }
  end
end

ActiveRecord::Base.shared_connection = ActiveRecord::Base.connection

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join('spec/fixtures')]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  
  # Shoulda matchers
  Shoulda::Matchers.configure do |config|
    config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end

  Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }
  
  # Devise helpers
  config.include Devise::Test::IntegrationHelpers, type: :feature
  config.include Devise::Test::IntegrationHelpers, type: :system
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::ControllerHelpers, type: :controller
  
  # Other helpers
  config.include Warden::Test::Helpers
  config.include FactoryBot::Syntax::Methods
  config.include ActiveJob::TestHelper

  # Save screenshots on failure for JavaScript tests
  config.after(:each, type: :feature, js: true) do |example|
    if example.exception
      page.save_screenshot("tmp/capybara/#{example.full_description.parameterize}.png")
    end
  end

  # Clean up uploaded screenshots
  config.after(:suite) do
    FileUtils.rm_rf("tmp/capybara")
  end
end