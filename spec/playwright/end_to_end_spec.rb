require 'rails_helper'
require 'playwright'
require 'net/http'
require 'puma'
require 'puma/configuration'
require 'puma/launcher'

RSpec.describe "End-to-End Integration (Playwright)", type: :request do
  PLAYWRIGHT_PORT = 3999
  PLAYWRIGHT_HOST = "127.0.0.1"
  PLAYWRIGHT_BASE_URL = "http://#{PLAYWRIGHT_HOST}:#{PLAYWRIGHT_PORT}"

  before(:all) do
    WebMock.allow_net_connect!(net_http_connect_on_start: true)

    puma_config = Puma::Configuration.new do |config|
      config.app Rails.application
      config.bind "tcp://#{PLAYWRIGHT_HOST}:#{PLAYWRIGHT_PORT}"
      config.workers 0
      config.threads 1, 1
      config.environment "test"
      config.log_requests false
      config.quiet
    end

    @puma_launcher = Puma::Launcher.new(puma_config)
    @server_thread = Thread.new { @puma_launcher.run }

    30.times do
      begin
        Net::HTTP.get(URI("#{PLAYWRIGHT_BASE_URL}/up"))
        break
      rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL
        sleep 0.5
      end
    end
  end

  after(:all) do
    @puma_launcher&.stop
    @server_thread&.join(5)
    WebMock.disable_net_connect!
  end

  before(:each) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.start
  end

  after(:each) do
    DatabaseCleaner.clean
  end

  let(:playwright_version) { Playwright::COMPATIBLE_PLAYWRIGHT_VERSION }

  def with_playwright(&block)
    Playwright.create(
      playwright_cli_executable_path: "npx playwright@#{playwright_version}"
    ) do |playwright|
      browser = playwright.chromium.launch(headless: true)
      context = browser.new_context
      page = context.new_page
      begin
        yield page
      ensure
        browser.close
      end
    end
  end

  describe "Regular user journey" do
    it "registers, signs in, sets preferences, and triggers email delivery" do
      topic = Topic.create!(name: "Technology", active: true)
      rss_source = NewsSource.create!(
        name: "Test RSS Feed",
        url: "https://example.com/rss",
        format: "rss",
        active: true,
        topic: topic
      )

      with_playwright do |page|
        # 1. Register — redirects to preferences/edit after sign-up
        page.goto("#{PLAYWRIGHT_BASE_URL}/users/sign_up")
        page.fill('input[name="user[name]"]', "Test User")
        page.fill('input[name="user[email]"]', "playwright@example.com")
        page.fill('input[name="user[password]"]', "password123")
        page.fill('input[name="user[password_confirmation]"]', "password123")

        page.expect_navigation do
          page.click('input[type="submit"][value="Sign up"]')
        end

        expect(page.content).to include("Signed in successfully").or include("Manage Your Preferences")

        user = User.find_by(email: "playwright@example.com")
        expect(user).to be_present

        # 2. Set preferences
        page.goto("#{PLAYWRIGHT_BASE_URL}/preferences/edit")
        page.wait_for_selector('.page-title', timeout: 10000)
        expect(page.content).to include("Manage Your Preferences")

        # Check the RSS source checkbox
        page.check("#source_#{rss_source.id}")

        page.expect_navigation do
          page.click('input[type="submit"][value="Save Preferences"]')
        end

        expect(page.content).to include("Preferences updated successfully")

        # Verify preferences persisted
        user.reload
        expect(user.news_sources).to include(rss_source)
      end
    end
  end

  describe "Admin user journey" do
    it "signs in, views dashboard, manages news sources, and previews articles" do
      admin = User.create!(
        email: "admin-pw@example.com",
        password: "password123",
        password_confirmation: "password123",
        name: "Admin",
        admin: true
      )
      topic = Topic.create!(name: "Technology", active: true)
      rss_source = NewsSource.create!(
        name: "Test RSS Feed",
        url: "https://example.com/rss",
        format: "rss",
        active: true,
        topic: topic
      )

      with_playwright do |page|
        # 1. Admin login
        page.goto("#{PLAYWRIGHT_BASE_URL}/users/sign_in")
        page.fill('input[name="user[email]"]', "admin-pw@example.com")
        page.fill('input[name="user[password]"]', "password123")

        page.expect_navigation do
          page.click('input[type="submit"][value="Sign in"]')
        end

        expect(page.content).to include("Signed in successfully")

        # 2. Visit admin dashboard
        page.goto("#{PLAYWRIGHT_BASE_URL}/admin/dashboard")
        page.wait_for_selector('.stat-card', timeout: 10000)
        expect(page.content).to include("Admin Dashboard")

        # 3. View news sources
        page.goto("#{PLAYWRIGHT_BASE_URL}/admin/news_sources")
        page.wait_for_selector('table', timeout: 10000)
        expect(page.content).to include("News Sources")
        expect(page.content).to include("Test RSS Feed")

        # 4. Create a new source via fetch (forgery protection disabled in test)
        page.evaluate(<<~JS, arg: { base: PLAYWRIGHT_BASE_URL })
          async ({ base }) => {
            const form = new URLSearchParams();
            form.append('news_source[name]', 'Hacker News');
            form.append('news_source[url]', 'https://hnrss.org/frontpage');
            form.append('news_source[format]', 'rss');
            form.append('news_source[is_validated]', 'true');
            await fetch(`${base}/admin/news_sources`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
              body: form.toString(),
              credentials: 'include'
            });
          }
        JS

        page.goto("#{PLAYWRIGHT_BASE_URL}/admin/news_sources")
        page.wait_for_selector('table', timeout: 10000)
        expect(page.content).to include("Hacker News")

        # 5. Edit existing source
        page.evaluate(<<~JS, arg: { base: PLAYWRIGHT_BASE_URL, id: rss_source.id })
          async ({ base, id }) => {
            const form = new URLSearchParams();
            form.append('news_source[name]', 'Updated RSS Feed');
            form.append('news_source[url]', 'https://example.com/rss');
            form.append('news_source[format]', 'rss');
            form.append('news_source[active]', 'true');
            form.append('news_source[is_validated]', 'true');
            form.append('_method', 'put');
            await fetch(`${base}/admin/news_sources/${id}`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
              body: form.toString(),
              credentials: 'include'
            });
          }
        JS

        page.goto("#{PLAYWRIGHT_BASE_URL}/admin/news_sources")
        page.wait_for_selector('table', timeout: 10000)
        expect(page.content).to include("Updated RSS Feed")

        # 6. Preview articles from source
        rss_source.reload
        page.goto("#{PLAYWRIGHT_BASE_URL}/admin/news_sources/#{rss_source.id}/preview")
        page.wait_for_selector('.page-title', timeout: 10000)
        expect(page.content).to include("Preview: Updated RSS Feed")
      end
    end
  end
end
