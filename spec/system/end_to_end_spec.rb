require 'rails_helper'

RSpec.describe "End-to-End Integration", type: :system do
  before do
    driven_by(:rack_test)
    
    # Create test sources
    @rss_source = create(:source, 
      name: "Test RSS Feed", 
      url: "https://example.com/rss", 
      source_type: "rss", 
      active: true
    )
    
    @api_source = create(:source, 
      name: "Test API", 
      url: "https://newsapi.org/v2/top-headlines", 
      source_type: "api", 
      active: true
    )
    
    @scrape_source = create(:source, 
      name: "Test Scrape Site", 
      url: "https://example.com/news", 
      source_type: "scrape", 
      active: true,
      selectors: {
        article: ".article",
        title: "h2",
        content: ".content",
        published_at: ".date"
      }
    )
    
    # Mock the ArticleFetcher service
    allow(ArticleFetcher).to receive(:fetch_for_user).and_return([
      {
        title: "Test Article 1",
        content: "This is a test article about technology",
        url: "https://example.com/article1",
        published_at: Time.current,
        source: "Test RSS Feed",
        categories: ["technology"]
      },
      {
        title: "Test Article 2",
        content: "This is a test article about science",
        url: "https://example.com/article2",
        published_at: Time.current,
        source: "Test API",
        categories: ["science"]
      },
      {
        title: "Test Article 3",
        content: "This is a test article about business",
        url: "https://example.com/article3",
        published_at: Time.current,
        source: "Test Scrape Site",
        categories: ["business"]
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
    
    # 4. Generate and deliver daily email using your existing DailyEmailJob
    # This would normally be done by a scheduled job, but we'll simulate it here
    DailyEmailJob.perform_now(user)
    
    # Verify email was sent
    expect(DailyNewsMailer).to have_received(:daily_digest)
    
    # 5. Simulate email delivery failure and retry
    allow(DailyNewsMailer).to receive(:daily_digest).and_raise(StandardError.new("SMTP error"))
    
    # This should trigger the retry mechanism in your DailyEmailJob
    expect {
      DailyEmailJob.perform_now(user)
    }.to raise_error(StandardError)
    
    # After 3 failures, the job should discard and purge the user
    # We'll simulate this by calling the discard_on block directly
    job = DailyEmailJob.new
    job.arguments = [user]
    
    # Get the discard_on block from the job class
    discard_block = DailyEmailJob.instance_variable_get(:@discard_on_callbacks).first.last
    
    # Call the discard block with the job and error
    discard_block.call(job, StandardError.new("SMTP error"))
    
    # Verify the user was purged
    expect(User.exists?(user.id)).to be_falsey
  end
  
  scenario "Admin user journey for managing the system" do
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
    
    # 3. Check sources management
    visit admin_sources_path
    expect(page).to have_content("Content Sources")
    expect(page).to have_content("Test RSS Feed")
    expect(page).to have_content("Test API")
    expect(page).to have_content("Test Scrape Site")
    
    # 4. Check user management
    visit admin_users_path
    expect(page).to have_content("Users")
    
    # 5. Check email metrics
    visit admin_email_metrics_path
    expect(page).to have_content("Email Metrics")
    
    # 6. Add a new source
    visit new_admin_source_path
    fill_in "Name", with: "New Test Source"
    fill_in "URL", with: "https://example.com/new-source"
    select "RSS Feed", from: "Source type"
    check "Active"
    click_button "Create Source"
    
    expect(page).to have_content("Source was successfully created")
    expect(page).to have_content("New Test Source")
    
    # 7. Create a regular user
    visit new_admin_user_path
    fill_in "Email", with: "newuser@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"
    click_button "Create User"
    
    expect(page).to have_content("User was successfully created")
    
    # 8. View the new user's details
    new_user = User.find_by(email: "newuser@example.com")
    visit admin_user_path(new_user)
    expect(page).to have_content("newuser@example.com")
    
    # 9. Run the daily email job for all users
    click_link "Send Daily Emails"
    expect(page).to have_content("Daily emails have been queued for delivery")
    
    # 10. View email metrics after sending
    visit admin_email_metrics_path
    expect(page).to have_content("sent")
  end
end