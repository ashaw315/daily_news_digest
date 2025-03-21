require 'rails_helper'

RSpec.describe "Preferences", type: :request do
  let(:user) { create(:user) }

  describe "when not signed in" do
    it "redirects to login" do
      get edit_preferences_path
      expect(response).to redirect_to(new_user_session_path)

      patch preferences_path
      expect(response).to redirect_to(new_user_session_path)

      post reset_preferences_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "when signed in" do
    before { sign_in user }

    describe "GET /preferences/edit" do
      it "returns http success" do
        get edit_preferences_path
        expect(response).to have_http_status(:success)
      end
    end

    describe "PATCH /preferences" do
      let(:valid_preferences) do
        {
          user: {
            preferences: {
              topics: ['technology'],
              sources: ['news_api'],
              frequency: 'daily'
            }
          }
        }
      end

      it "updates user preferences" do
        patch preferences_path, params: valid_preferences
        expect(response).to redirect_to(edit_preferences_path)
        expect(user.reload.selected_topics).to include('technology')
      end
    end

    describe "POST /preferences/reset" do
      before do
        user.update!(preferences: {
          'topics' => ['technology'],
          'sources' => ['news_api'],
          'frequency' => 'weekly'
        })
      end

      it "resets preferences to defaults" do
        post reset_preferences_path
        expect(response).to redirect_to(edit_preferences_path)
        user.reload
        expect(user.selected_topics).to be_empty
        expect(user.selected_sources).to be_empty
        expect(user.email_frequency).to eq('daily')
      end
    end
  end
end
