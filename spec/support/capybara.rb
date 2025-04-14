require "selenium/webdriver"

# Enable auto-loading of support files
Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

# Register Chrome Headless
Capybara.register_driver :chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless")
  options.add_argument("--disable-gpu")
  options.add_argument("--window-size=1400,1400")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

# Configure Capybara
Capybara.configure do |config|
  config.default_driver = :rack_test
  config.javascript_driver = :chrome_headless
  config.default_max_wait_time = 5
  config.server = :puma, { Silent: true }
end

# Set up system tests
RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    driven_by :chrome_headless
  end
end