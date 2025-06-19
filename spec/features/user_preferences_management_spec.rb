require 'rails_helper'

RSpec.describe "User Preferences Management", type: :feature do
  let(:user) { create(:user) }
  let(:valid_rss_response) {
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Test Feed</title>
          <link>https://example.com</link>
          <description>Test RSS Feed</description>
          <item>
            <title>Test Article</title>
            <link>https://example.com/article1</link>
            <description>Test Description</description>
            <pubDate>#{Time.now.rfc2822}</pubDate>
          </item>
        </channel>
      </rss>
    XML
  }

  describe "editing preferences" do
    before do
      # Create topics
      @technology_topic = Topic.create!(name: 'technology', active: true)
      @science_topic = Topic.create!(name: 'science', active: true)
      @politics_topic = Topic.create!(name: 'politics', active: true)
  
      # Create news sources
      @cnn_source = NewsSource.create!(
        name: 'CNN', 
        format: 'rss', 
        url: 'https://rss.cnn.com/rss/cnn_topstories.rss',
        active: true
      )
      @bbc_source = NewsSource.create!(
        name: 'BBC', 
        format: 'rss', 
        url: 'https://feeds.bbci.co.uk/news/rss.xml',
        active: true
      )
      @reuters_source = NewsSource.create!(
        name: 'Reuters', 
        format: 'rss', 
        url: 'https://www.reutersagency.com/feed/',
        active: true
      )

      # Stub RSS feed validations
      stub_request(:get, "https://rss.cnn.com/rss/cnn_topstories.rss")
        .to_return(status: 200, body: valid_rss_response, headers: { 'Content-Type' => 'application/rss+xml' })
      stub_request(:get, "https://feeds.bbci.co.uk/news/rss.xml")
        .to_return(status: 200, body: valid_rss_response, headers: { 'Content-Type' => 'application/rss+xml' })
      stub_request(:get, "https://www.reutersagency.com/feed/")
        .to_return(status: 200, body: valid_rss_response, headers: { 'Content-Type' => 'application/rss+xml' })

      sign_in user
    end

    it "requires at least 3 topics and 1 source" do
      visit edit_preferences_path
      
      uncheck "topic_#{@politics_topic.name.downcase}"
      click_button "Save Preferences"
      expect(page).to have_content("You must select at least 3 topics")

      check "topic_#{@politics_topic.name.downcase}"
      uncheck "source_#{@cnn_source.name.downcase}"
      click_button "Save Preferences"
      expect(page).to have_content("You must select at least 1 news source")

      check "source_#{@cnn_source.name.downcase}"
      choose "Weekly"
      click_button "Save Preferences"
      expect(page).to have_content("Preferences updated successfully")
      
      visit edit_preferences_path
      expect(page).to have_checked_field("topic_#{@technology_topic.name.downcase}")
      expect(page).to have_checked_field("topic_#{@science_topic.name.downcase}")
      expect(page).to have_checked_field("topic_#{@politics_topic.name.downcase}")
      expect(page).to have_checked_field("source_#{@cnn_source.name.downcase}")
      expect(page).to have_checked_field("frequency_weekly")
    end
  end

  describe "resetting preferences", js: true do
    before do
      # Create topics
      @technology_topic = Topic.create!(name: 'technology', active: true)
      @science_topic = Topic.create!(name: 'science', active: true)
      @politics_topic = Topic.create!(name: 'politics', active: true)
  
      # Create news sources
      @cnn_source = NewsSource.create!(
        name: 'CNN', 
        format: 'rss', 
        url: 'https://rss.cnn.com/rss/cnn_topstories.rss',
        active: true
      )
      @bbc_source = NewsSource.create!(
        name: 'BBC', 
        format: 'rss', 
        url: 'https://feeds.bbci.co.uk/news/rss.xml',
        active: true
      )
      @reuters_source = NewsSource.create!(
        name: 'Reuters', 
        format: 'rss', 
        url: 'https://www.reutersagency.com/feed/',
        active: true
      )

      # Stub RSS feed validations
      stub_request(:get, "https://rss.cnn.com/rss/cnn_topstories.rss")
        .to_return(status: 200, body: valid_rss_response, headers: { 'Content-Type' => 'application/rss+xml' })
      stub_request(:get, "https://feeds.bbci.co.uk/news/rss.xml")
        .to_return(status: 200, body: valid_rss_response, headers: { 'Content-Type' => 'application/rss+xml' })
      stub_request(:get, "https://www.reutersagency.com/feed/")
        .to_return(status: 200, body: valid_rss_response, headers: { 'Content-Type' => 'application/rss+xml' })

      sign_in user
    end

    it "allows users to reset their preferences" do
      visit edit_preferences_path
      
      # Set non-default preferences
      check "topic_#{@technology_topic.name.downcase}"
      check "topic_#{@science_topic.name.downcase}"
      check "topic_#{@politics_topic.name.downcase}"
      check "source_#{@bbc_source.name.downcase}"
      choose "Weekly"
      
      click_button "Save Preferences"
      expect(page).to have_content("Preferences updated successfully", wait: 5)
      
      # Reset preferences
      click_button "Reset Preferences"
      expect(page).to have_selector('#reset-modal', visible: true, wait: 5)
      
      within('#reset-modal') do
        click_button "Yes, Reset"
      end
      
      expect(page).to have_content("Preferences have been reset", wait: 5)
      
      # Verify reset in database
      user.reload
      expect(user.topics.count).to eq(3)
      expect(user.topics).to include(@technology_topic, @science_topic, @politics_topic)
      expect(user.news_sources.count).to eq(1)
      expect(user.news_sources).to include(@cnn_source)
      expect(user.preferences.email_frequency).to eq('daily')
    end

    it "cancels reset when clicking cancel in modal" do
      visit edit_preferences_path

      click_button "Reset Preferences"
      expect(page).to have_selector('#reset-modal', visible: true, wait: 5)
      
      within('#reset-modal') do
        click_button "Cancel"
      end
      
      expect(page).to have_selector('#reset-modal', visible: false, wait: 5)
      
      # Verify preferences unchanged
      expect(page).to have_checked_field("topic_#{@technology_topic.name.downcase}")
      expect(page).to have_checked_field("topic_#{@science_topic.name.downcase}")
      expect(page).to have_checked_field("topic_#{@politics_topic.name.downcase}")
      expect(page).to have_checked_field("source_#{@cnn_source.name.downcase}")
      expect(page).to have_checked_field("frequency_daily")
    end
  end

  describe "navigation" do
    before do
      sign_in user
    end

    it "can access preferences from navigation menu" do
      visit root_path
      expect(page).to have_link("Edit Preferences")
      click_link "Edit Preferences"
      expect(page).to have_current_path(edit_preferences_path)
    end
  end
end