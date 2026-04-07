require 'rails_helper'

RSpec.describe 'Authentication', type: :request do
  let(:user) { create(:user) }

  describe 'POST /users/sign_in' do
    it 'sets a session cookie on successful login' do
      post user_session_path, params: {
        user: { email: user.email, password: 'password123' }
      }

      expect(response).to redirect_to(edit_preferences_path)
      expect(response.headers['Set-Cookie']).to be_present
    end
  end

  describe 'DELETE /users/sign_out' do
    before { sign_in user }

    it 'clears the session on logout' do
      delete destroy_user_session_path

      expect(response).to redirect_to(root_path)
      # After logout, accessing a protected page should redirect to login
      get edit_preferences_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'protected endpoint without authentication' do
    it 'redirects to sign in for HTML requests' do
      get edit_preferences_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
