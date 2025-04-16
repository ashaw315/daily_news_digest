require 'rails_helper'

RSpec.describe "End-to-End Integration", type: :system do
  before do
    driven_by(:rack_test)
    
    # Create test RSS source
    @rss_source = create(:news_source, 
      name: "Test RSS Feed", 
      url: "https://example.com/rss", 
      format: "rss",  # Changed from source_type to format
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
    
    # Mock the ArticleFetcher service
    allow(ArticleFetcher).to receive(:fetch_for_user).and_return([
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
    ])
    
    # Mock the email delivery service
    allow(DailyNewsMailer).to receive(:daily_digest).and_return(
      double(deliver_now: true, deliver_later: true)
    )
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
    click_button "Log in"
    
    expect(page).to have_content("Signed in successfully")
    
    # 3. Set User Preferences
    visit edit_preferences_path
    
    # Select topics
    check "Technology"
    check "Science"
    
    # Select email frequency
    choose "Daily"
    
    click_button "Update Preferences"
    
    expect(page).to have_content("Preferences updated successfully")
    
    # Verify preferences were saved
    user.reload
    expect(user.preferences.topics).to include("technology", "science")
    expect(user.preferences.email_frequency).to eq("daily")
    
    # 4. Generate and deliver daily email
    DailyEmailJob.perform_now(user)
    
    # Verify email was sent
    expect(DailyNewsMailer).to have_received(:daily_digest)
  end
  
  scenario "Admin user journey for managing news sources" do
    # Create admin user
    admin = create(:user, email: "admin@example.com", admin: true)
    
    # 1. Admin Login
    visit new_user_session_path
    fill_in "Email", with: "admin@example.com"
    fill_in "Password", with: "password123"
    click_button "Log in"
    
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
    fill_in "RSS Feed URL", with: "https://hnrss.org/frontpage"
    
    # Click validate and wait for response
    click_button "Validate RSS Feed"
    expect(page).to have_content("RSS feed is valid", wait: 5)
    
    click_button "Create News Source"
    expect(page).to have_content("News source was successfully created")
    
    # 5. Try to delete a source that's in use
    news_source_with_articles = create(:news_source)
    create(:article, news_source: news_source_with_articles)
    
    visit admin_news_sources_path
    within "#news_source_#{news_source_with_articles.id}" do
      expect(page).not_to have_button("Delete")
      expect(page).to have_content("In Use")
    end
    
    # 6. Edit an existing source
    within "#news_source_#{@rss_source.id}" do
      click_link "Edit"
    end
    
    fill_in "Name", with: "Updated RSS Feed"
    click_button "Update News Source"
    
    expect(page).to have_content("News source was successfully updated")
    expect(page).to have_content("Updated RSS Feed")
    
    # 7. Preview articles from a source
    within "#news_source_#{@rss_source.id}" do
      click_link "Preview"
    end
    
    expect(page).to have_content("Preview: Updated RSS Feed")
    expect(page).to have_content("Test Article 1")
    expect(page).to have_content("Test Article 2")
  end
end