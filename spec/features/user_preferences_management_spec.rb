require 'rails_helper'

RSpec.describe "User Preferences Management", type: :feature do
  let(:user) { create(:user) }

  describe "editing preferences" do
    before do
      # Create topics
      @technology_topic = Topic.create!(name: 'technology', active: true)
      @science_topic = Topic.create!(name: 'science', active: true)
      @politics_topic = Topic.create!(name: 'politics', active: true)
  
      # Create news sources
      @cnn_source = NewsSource.create!(name: 'CNN', format: 'api', active: true)
      @bbc_source = NewsSource.create!(name: 'BBC', format: 'rss', active: true)
      @reuters_source = NewsSource.create!(name: 'Reuters', format: 'web_scraped', active: true)
  
      sign_in user
    end

    it "requires at least 3 topics and 1 source" do
      visit edit_preferences_path
      
      uncheck "topic_#{@politics_topic.name.downcase}"
    
      click_button "Save Preferences"

      # Expect error message about topics
      expect(page).to have_content("You must select at least 3 topics")

      # binding.pry

      # Check the third topic again
      check "topic_#{@politics_topic.name.downcase}"
      
      # Now uncheck the news source
      uncheck "source_#{@cnn_source.name.downcase}"
      
      # Try to save with no news sources
      click_button "Save Preferences"

      # Expect error message about news sources
      expect(page).to have_content("You must select at least 1 news source")

      check "source_#{@cnn_source.name.downcase}"
      choose "Weekly"
      
      click_button "Save Preferences"
      # Expect success message
      expect(page).to have_content("Preferences updated successfully")
      
      # Verify selections persisted
      visit edit_preferences_path
      expect(page).to have_checked_field("topic_#{@technology_topic.name.downcase}")
      expect(page).to have_checked_field("topic_#{@science_topic.name.downcase}")
      expect(page).to have_checked_field("topic_#{@politics_topic.name.downcase}")
      expect(page).to have_checked_field("source_#{@cnn_source.name.downcase}")
      expect(page).to have_checked_field("frequency_weekly")
    end
  end

  describe "resetting preferences" do
    before do
       # Create topics
       @technology_topic = Topic.create!(name: 'technology', active: true)
       @science_topic = Topic.create!(name: 'science', active: true)
       @politics_topic = Topic.create!(name: 'politics', active: true)
   
       # Create news sources
       @cnn_source = NewsSource.create!(name: 'CNN', format: 'api', active: true)
       @bbc_source = NewsSource.create!(name: 'BBC', format: 'rss', active: true)
       @reuters_source = NewsSource.create!(name: 'Reuters', format: 'web_scraped', active: true)
   
       sign_in user
    end

    it "allows users to reset their preferences", js: true do
      visit edit_preferences_path
      
      # First, select some non-default preferences
      check "topic_#{@technology_topic.name.downcase}"
      check "topic_#{@science_topic.name.downcase}"
      check "topic_#{@politics_topic.name.downcase}"
      check "source_#{@bbc_source.name.downcase}"  # Select BBC instead of CNN
      choose "Weekly"  # Select weekly instead of daily
      
      click_button "Save Preferences"
      expect(page).to have_content("Preferences updated successfully")
      
      # Now reset preferences
      click_button "Reset Preferences"
      
      # Check that the modal appears
      expect(page).to have_selector('#reset-modal', visible: true)
      
      # Debug - print the modal content
      puts "Modal content:"
      puts page.find('#reset-modal').text
      
      # Confirm reset in the modal
      within('#reset-modal') do
        click_button "Yes, Reset"
      end
      
      # Debug - print the page content
      puts "Page content after reset:"
      puts page.body
      
      # Check for success message
      expect(page).to have_content("Preferences have been reset")
      
      # Verify preferences were reset to defaults in the database
      user.reload
      
      # Should have the first 3 topics
      expect(user.topics.count).to eq(3)
      expect(user.topics).to include(@technology_topic, @science_topic, @politics_topic)
      
      # Should have the first news source
      expect(user.news_sources.count).to eq(1)
      expect(user.news_sources).to include(@cnn_source)
      
      # Should have default email frequency
      expect(user.preferences.email_frequency).to eq('daily')
    end

    it "cancels reset when clicking cancel in modal", js: true do
      visit edit_preferences_path

      click_button "Reset Preferences"
      
      within('#reset-modal') do
        click_button "Cancel"
      end
      
      # Modal should be hidden
      expect(page).to have_selector('#reset-modal', visible: false)
      
      # Preferences should remain unchanged (default preferences)
      expect(page).to have_checked_field("topic_#{@technology_topic.name.downcase}")
      expect(page).to have_checked_field("topic_#{@science_topic.name.downcase}")
      expect(page).to have_checked_field("topic_#{@politics_topic.name.downcase}")
      expect(page).to have_checked_field("source_#{@cnn_source.name.downcase}")
      expect(page).to have_checked_field("frequency_daily")
    end
  end

  describe "navigation" do
    it "can access preferences from navigation menu" do
      sign_in user
      visit root_path
      expect(page).to have_link("Manage Preferences")
      click_link "Manage Preferences"
      expect(page).to have_current_path(edit_preferences_path)
    end
  end
end