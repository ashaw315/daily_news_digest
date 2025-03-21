require 'rails_helper'

RSpec.feature "User Unsubscribe", type: :feature do
  let!(:user) { create(:user, is_subscribed: true) }
  
  scenario "User unsubscribes using the link in the email" do
    # Store the user ID for later lookup
    user_id = user.id
    
    # Visit the unsubscribe URL with the user's token
    visit unsubscribe_path(token: user.unsubscribe_token)
    
    # Should be redirected to the home page
    expect(current_path).to eq(root_path)
    
    # Should see a success message
    expect(page).to have_content('You have been successfully unsubscribed from our emails.')
    
    # Verify the user is unsubscribed by loading a fresh instance
    expect(User.find(user_id).is_subscribed).to be false
  end
  
  scenario "User tries to unsubscribe with an invalid token" do
    # Visit the unsubscribe URL with an invalid token
    visit unsubscribe_path(token: 'invalid-token')
    
    # Should be redirected to the home page
    expect(current_path).to eq(root_path)
    
    # Should see an error message
    expect(page).to have_content('Invalid unsubscribe token.')
  end
end 