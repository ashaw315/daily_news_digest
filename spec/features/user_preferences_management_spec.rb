require 'rails_helper'

RSpec.describe "User Preferences Management", type: :feature do
  let(:user) { create(:user) }

  before do
    sign_in user
    visit edit_preferences_path
  end

  describe "editing preferences" do
    before do
      user.update!(preferences: {
        'topics' => ['technology', 'science'],
        'sources' => ['news_api'],
        'frequency' => 'weekly'
      })
      visit edit_preferences_path
    end

    it "allows users to update their preferences" do
      # Debug output
      puts "User preferences: #{user.reload.preferences.inspect}"
      puts "Checkbox states: #{page.all('input[type="checkbox"]').map { |cb| [cb['id'], cb['checked']] }.inspect}"
      
      expect(find("#topic_technology")).to be_checked
      expect(find("#topic_science")).to be_checked
      
      # Check news sources
      check "source_news_api"
      
      # Select frequency
      choose "frequency_daily"
      
      click_button "Save Preferences"
    #   binding.pry
      # Verify success message
      expect(page).to have_content("Preferences updated successfully")
      
      # Verify selections persisted
      visit edit_preferences_path
      expect(page).to have_checked_field("topic_technology")
      expect(page).to have_checked_field("topic_science")
      expect(page).to have_checked_field("source_news_api")
      expect(page).to have_checked_field("frequency_daily")
    end

    it "shows validation errors when no options are selected" do
      visit edit_preferences_path
      
      # Uncheck all checkboxes
      all('input[type="checkbox"]').each do |checkbox|
        checkbox.uncheck if checkbox.checked?
      end
      
      click_button "Save Preferences"
      
      # Updated expectation to match the actual error message
      expect(page).to have_content("Preferences can't be blank")
      
      # Verify we're still on the edit page
      expect(current_path).to eq(edit_preferences_path)
    end
  end

  describe "resetting preferences" do
    before do
      sign_in user
      user.update!(preferences: {
        'topics' => ['technology', 'science'],
        'sources' => ['news_api'],
        'frequency' => 'weekly'
      })
      visit edit_preferences_path
    end

    it "allows users to reset their preferences", js: true do
      # Click the reset button
      click_button "Reset Preferences"
      
      # Check that the modal appears
      expect(page).to have_selector('#reset-modal', visible: true)
      
      # Confirm reset in the modal
      within('#reset-modal') do
        click_button "Yes, Reset"
      end
      
      # Check for success message
      expect(page).to have_content("Preferences have been reset")
      
      # Verify preferences were actually reset in the database
      user.reload
      expect(user.preferences).to eq({"frequency"=>"daily", "sources"=>[], "topics"=>[]})
      
    end

    it "cancels reset when clicking cancel in modal", js: true do
      click_button "Reset Preferences"
      
      within('#reset-modal') do
        click_button "Cancel"
      end
      
      # Modal should be hidden
      expect(page).to have_selector('#reset-modal', visible: false)
      
      # Preferences should remain unchanged
      user.reload
      expect(user.selected_topics).to contain_exactly('technology', 'science')
    end
  end

  describe "navigation" do
    it "can access preferences from navigation menu" do
      visit root_path
      expect(page).to have_link("Manage Preferences")
      click_link "Manage Preferences"
      expect(page).to have_current_path(edit_preferences_path)
    end
  end
end