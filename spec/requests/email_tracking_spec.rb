require 'rails_helper'

RSpec.describe EmailTrackingController, type: :request do
  include ActiveSupport::Testing::TimeHelpers

  describe 'GET /email/track/:token' do
    let(:user) { create(:user) }
    let(:tracking) { create(:email_tracking, user: user) }

    it 'increments open_count and returns a GIF with a valid token' do
      expect {
        get email_tracking_path(token: tracking.token)
      }.to change { tracking.reload.open_count }.by(1)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('image/gif')
    end

    it 'returns a GIF with an invalid token (never 404)' do
      get email_tracking_path(token: 'nonexistent-token')

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('image/gif')
    end

    it 'sets opened_at on first open only' do
      expect(tracking.opened_at).to be_nil

      freeze_time do
        get email_tracking_path(token: tracking.token)
        tracking.reload
        first_opened_at = tracking.opened_at
        expect(first_opened_at).to eq(Time.current)

        # Second open should not update opened_at
        travel 1.hour
        get email_tracking_path(token: tracking.token)
        tracking.reload
        expect(tracking.opened_at).to eq(first_opened_at)
        expect(tracking.open_count).to eq(2)
      end
    end
  end
end
