require 'rails_helper'

RSpec.describe 'User authentication', type: :feature do
  let(:user_attributes) { { email: 'test@example.com', password: 'password123', name: 'Name' } }

  describe 'sign up' do
    it 'allows user to sign up with valid credentials', js: true do
      visit new_user_registration_path
      
      # Debug: Print the current page HTML
      puts page.html
      
      # Debug: List all form fields
      puts "Form fields:"
      page.all('input').each do |input|
        puts "#{input[:name]}: #{input[:type]}"
      end
      
      # Fill in all fields including name
      fill_in 'Name', with: user_attributes[:name]
      fill_in 'Email', with: user_attributes[:email]
      fill_in 'Password', with: user_attributes[:password]
      fill_in 'Password confirmation', with: user_attributes[:password]
      
      click_button 'Sign up'
        # Debug: Print the current page HTML
      puts "Page HTML after clicking Sign up:"
      puts page.html
      
      # Debug: Print all text on the page
      puts "All text on page:"
      puts page.text
      
      # Check for the confirmation message with a more specific matcher
      # binding.pry
      expect(page).to have_css('.alert-success', text: /confirmation link/)
      
      # Check that a user was created
      expect(User.count).to eq(1)
    end
  end

  describe 'confirmation' do
    let!(:user) { User.create(user_attributes) }

    it 'confirms user account with valid token' do
      visit user_confirmation_path(confirmation_token: user.confirmation_token)
      expect(page).to have_content('Your email address has been successfully confirmed')
      expect(user.reload.confirmed?).to be_truthy
    end
  end

  describe 'sign in' do
    let!(:user) { User.create(user_attributes.merge(confirmed_at: Time.current)) }

    it 'allows confirmed user to sign in' do
      visit new_user_session_path
      
      fill_in 'Email', with: user_attributes[:email]
      fill_in 'Password', with: user_attributes[:password]
      click_button 'Sign in'
      
      expect(page).to have_content('Signed in successfully')
    end
  end

  describe 'password reset' do
    let!(:user) { User.create!(user_attributes.merge(confirmed_at: Time.current)) }

    it 'sends password reset instructions' do
      visit new_user_password_path
      
      expect {
        fill_in 'Email', with: user_attributes[:email]
        click_button 'Send Recovery Instructions'
        sleep 1 # Give it a moment to process
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
      
      expect(page).to have_content('You will receive an email with instructions')
    end
  end
end
