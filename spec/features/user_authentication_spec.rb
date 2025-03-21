require 'rails_helper'

RSpec.describe 'User authentication', type: :feature do
  let(:user_attributes) { { email: 'test@example.com', password: 'password123' } }

  describe 'sign up' do
    it 'allows user to sign up with valid credentials' do
      visit new_user_registration_path
      
      expect {
        fill_in 'Email', with: user_attributes[:email]
        fill_in 'Password', with: user_attributes[:password]
        fill_in 'Password confirmation', with: user_attributes[:password]
        
        click_button 'Sign up'
        sleep 1 # Give it a moment to process
      }.to change(User, :count).by(1)
         .and change { ActionMailer::Base.deliveries.count }.by(1)
      
      expect(page).to have_content('A message with a confirmation link')
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
      click_button 'Log in'
      
      expect(page).to have_content('Signed in successfully')
    end
  end

  describe 'password reset' do
    let!(:user) { User.create!(user_attributes.merge(confirmed_at: Time.current)) }

    it 'sends password reset instructions' do
      visit new_user_password_path
      
      expect {
        fill_in 'Email', with: user_attributes[:email]
        click_button 'Send me reset password instructions'
        sleep 1 # Give it a moment to process
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
      
      expect(page).to have_content('You will receive an email with instructions')
    end
  end
end
