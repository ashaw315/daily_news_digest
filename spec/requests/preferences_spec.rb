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
      let!(:technology_topic) { create(:topic, name: 'technology') }
      let!(:science_topic) { create(:topic, name: 'science') }
      let!(:health_topic) { create(:topic, name: 'health') }
      let!(:news_api_source) { create(:news_source, name: 'news_api') }
      
      let(:valid_preferences) do
        {
          user: {
            topic_ids: [technology_topic.id, science_topic.id, health_topic.id],
            news_source_ids: [news_api_source.id],
            preferences_attributes: {
              id: user.preferences.id,  # Important: include the ID for update
              email_frequency: 'daily'
            }
          }
        }
      end

      it "updates user preferences" do
        # First, make sure the user meets the minimum requirements
        # to avoid validation errors
        user.topics << technology_topic
        user.topics << science_topic
        user.topics << health_topic
        user.news_sources << news_api_source
        
        # Now update with our preferences
        patch preferences_path, params: valid_preferences
        
        # Debug output if the test fails
        if response.status == 422
          puts "Response body: #{response.body}"
        end
        
        expect(response).to redirect_to(edit_preferences_path)
        user.reload
        expect(user.topics).to include(technology_topic)
        expect(user.news_sources).to include(news_api_source)
        expect(user.preferences.email_frequency).to eq('daily')
      end
    end

    describe "POST /preferences/reset" do
      let!(:technology_topic) { create(:topic, name: 'technology') }
      let!(:science_topic) { create(:topic, name: 'science') }
      let!(:health_topic) { create(:topic, name: 'health') }
      let!(:news_api_source) { create(:news_source, name: 'news_api') }
      
      before do
        # Clear existing associations
        user.topics.clear
        user.news_sources.clear
        
        # Associate user with topics and sources
        user.topics << technology_topic
        user.topics << science_topic
        user.topics << health_topic
        user.news_sources << news_api_source
        
        # Update preferences record
        user.preferences.update!(email_frequency: 'weekly')
        
        # Verify setup
        user.reload
        expect(user.topics.count).to eq(3)
        expect(user.news_sources.count).to eq(1)
      end

      it "resets preferences to defaults" do
        post reset_preferences_path
        
        expect(response).to redirect_to(edit_preferences_path)
        user.reload
        
        expect(user.topics.count).to eq(3)
        expect(user.news_sources.count).to eq(1)
        expect(user.preferences.email_frequency).to eq('daily')
      end
    end
  end
end