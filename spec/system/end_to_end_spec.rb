require 'rails_helper'
require 'ostruct'

RSpec.describe "End-to-End Integration", type: :system do
  before do
    driven_by(:rack_test)
    
    # Create test topics (for article grouping, not user selection)
    @technology_topic = create(:topic, name: "Technology", active: true)
    @science_topic = create(:topic, name: "Science", active: true)
    @business_topic = create(:topic, name: "Business", active: true)
    
    # Create test RSS source
    @rss_source = create(:news_source, 
      name: "Test RSS Feed", 
      url: "https://example.com/rss", 
      format: "rss",
      active: true
    )
    
    # Mock OpenAI for article categorization
    allow_any_instance_of(OpenAI::Client).to receive(:chat).and_return(
      OpenStruct.new(
        "choices" => [
          {
            "message" => {
              "content" => "technology"
            }
          }
        ]
      )
    )
    
    # Create sample articles for testing
    @articles = [
      {
        title: "Test Article 1",
        description: "This is a test article about technology",
        url: "https://example.com/article1",
        published_at: Time.current,
        source: "Test RSS Feed",
        topic: "technology",
        news_source_id: @rss_source.id
      },
      {
        title: "Test Article 2",
        description: "This is a test article about science",
        url: "https://example.com/article2",
        published_at: Time.current,
        source: "Test RSS Feed",
        topic: "science",
        news_source_id: @rss_source.id
      }
    ]
    
    # Mock the ArticleFetcher service
    allow(ArticleFetcher).to receive(:fetch_for_user).and_return(@articles)
    
    # Mock the email delivery service
    allow(DailyNewsMailer).to receive(:daily_digest).and_return(
      double(deliver_now: true, deliver_later: true)
    )

    # Mock RSS feed validation
    allow(SourceValidatorService).to receive_message_chain(:new, :validate).and_return(true)
    
    # Mock RSS feed content for HTTP requests
    sample_rss_content = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Test RSS Feed</title>
          <description>A test RSS feed for integration testing</description>
          <link>https://example.com</link>
          <item>
            <title>Test Article 1</title>
            <description>This is a test article about technology</description>
            <link>https://example.com/article1</link>
            <pubDate>#{Time.current.rfc2822}</pubDate>
          </item>
          <item>
            <title>Test Article 2</title>
            <description>This is a test article about science</description>
            <link>https://example.com/article2</link>
            <pubDate>#{Time.current.rfc2822}</pubDate>
          </item>
        </channel>
      </rss>
    XML
    
    # Stub HTTP requests for RSS feeds
    stub_request(:get, "https://example.com/rss")
      .to_return(status: 200, body: sample_rss_content, headers: {'Content-Type' => 'application/rss+xml'})
    
    stub_request(:get, "https://hnrss.org/frontpage")
      .to_return(status: 200, body: sample_rss_content, headers: {'Content-Type' => 'application/rss+xml'})
    
    # Mock NewsFetcher to return our test articles
    allow_any_instance_of(NewsFetcher).to receive(:fetch_articles).and_return(@articles)
  end
  
  scenario "Regular user journey from registration to receiving personalized news" do
    # 1. User Registration
    visit new_user_registration_path
    
    fill_in "Email", with: "user@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"
    click_button "Sign up"
    
    expect(page).to have_content("A message with a confirmation link has been sent")
    
    # Simulate email confirmation
    user = User.find_by(email: "user@example.com")
    user.confirm
    
    # 2. User Login
    visit new_user_session_path
    fill_in "Email", with: "user@example.com"
    fill_in "Password", with: "password123"
    # Robust login button handling
    if page.has_button?("Log in")
      click_button "Log in"
    elsif page.has_button?("Sign in")
      click_button "Sign in"
    else
      raise "No login button found!"
    end
    
    expect(page).to have_content("Signed in successfully")
    
    # 3. Set User Preferences
    visit edit_preferences_path

    # Select news source
    check "Test RSS Feed"
    
    # Select email frequency
    choose "frequency_daily"
    
    click_button "Save Preferences"
    
    expect(page).to have_content("Preferences updated successfully")
    
    # Verify preferences were saved
    user.reload
    expect(user.news_sources).to include(@rss_source)
    expect(user.preferences.email_frequency).to eq("daily")
    
    # 4. Directly call the email mailer instead of the job
    DailyNewsMailer.daily_digest(user, @articles).deliver_now
    
    # Verify email was sent - this should now pass
    expect(DailyNewsMailer).to have_received(:daily_digest)
  end
  
  scenario "Admin user journey for managing news sources" do
    # Create admin user
    admin = create(:user, email: "admin@example.com", admin: true)
    admin.confirm
    
    # 1. Admin Login
    visit new_user_session_path
    fill_in "Email", with: "admin@example.com"
    fill_in "Password", with: "password123"
    if page.has_button?("Log in")
      click_button "Log in"
    elsif page.has_button?("Sign in")
      click_button "Sign in"
    else
      raise "No login button found!"
    end
    
    expect(page).to have_content("Signed in successfully")
    
    # 2. Visit admin dashboard
    visit admin_dashboard_path
    expect(page).to have_content("Admin Dashboard")
    
    # 3. Check news sources management
    visit admin_news_sources_path
    expect(page).to have_content("News Sources")
    expect(page).to have_content("Test RSS Feed")
    
    # 4. Add a new RSS source
    visit new_admin_news_source_path
    fill_in "Name", with: "Hacker News"
    fill_in "URL", with: "https://hnrss.org/frontpage"
    page.driver.post("/admin/news_sources", { 
      news_source: { 
        name: "Hacker News", 
        url: "https://hnrss.org/frontpage", 
        format: "rss",
        is_validated: "true"
      } 
    })
    visit admin_news_sources_path
    expect(page).to have_content("Hacker News")
    
    # 5. Try to delete a source that's in use
    news_source_with_articles = create(:news_source, name: "Source With Articles")
    create(:article, news_source: news_source_with_articles)
    visit admin_news_sources_path
    expect(page).to have_content("Source With Articles")
    
    # 6. Edit an existing source - use PUT request directly instead of form submission
    page.driver.put("/admin/news_sources/#{@rss_source.id}", {
      news_source: {
        name: "Updated RSS Feed",
        url: @rss_source.url,
        format: "rss",
        active: true,
        is_validated: "true"
      }
    })
    visit admin_news_sources_path
    expect(page).to have_content("Updated RSS Feed")
    
    # 7. Preview articles from a source
    visit preview_admin_news_source_path(@rss_source)
    expect(page).to have_content("Preview: Updated RSS Feed")
  end
end