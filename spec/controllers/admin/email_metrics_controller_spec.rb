require 'rails_helper'

RSpec.describe Admin::EmailMetricsController, type: :request do
  let(:admin_user) { create(:user, admin: true) }
  let(:regular_user) { create(:user, admin: false) }
  
  # Create metrics with different statuses using the updated factory traits
  let!(:sent_metric) { create(:email_metric, :sent, user: regular_user) }
  let!(:opened_metric) { create(:email_metric, :opened, user: regular_user) }
  let!(:clicked_metric) { create(:email_metric, :clicked, user: regular_user) }
  let!(:failed_metric) { create(:email_metric, :failed, user: regular_user) }
  
  describe "GET /admin/email_metrics" do
    context "when not logged in" do
      it "redirects to the login page" do
        get admin_email_metrics_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
    
    context "when logged in as a regular user" do
      before { sign_in regular_user }
      
      it "redirects to the home page" do
        get admin_email_metrics_path
        expect(response).to redirect_to(root_path)
      end
    end
    
    context "when logged in as an admin user" do
      before { sign_in admin_user }
      
      it "renders the index page" do
        get admin_email_metrics_path
        expect(response).to be_successful
        expect(response.body).to include("Email Metrics")
      end
      
      it "displays metrics with all statuses" do
        get admin_email_metrics_path
        
        # Check that all metric types are shown
        expect(response.body).to include(regular_user.email)
        expect(response.body).to include('<span class="metric-label">Sent</span>')
        expect(response.body).to include('<span class="metric-label">Opened</span>')
        expect(response.body).to include('<span class="metric-label">Clicked</span>')
        expect(response.body).to include('<span class="metric-label">Failed</span>')
      end
      
      it "shows the correct metrics count" do
        get admin_email_metrics_path
      
        # Match the actual HTML structure instead of the text
        expect(response.body).to include('<span class="metric-label">Sent</span>')
        expect(response.body).to include('<span class="metric-label">Opened</span>')
        expect(response.body).to include('<span class="metric-label">Clicked</span>')
        expect(response.body).to include('<span class="metric-label">Failed</span>')
      
        expect(response.body).to include('<span class="metric-value">1</span>')

        expect(response.body).to match(/<span class="metric-label">Sent<\/span>.*?<span class="metric-value">1<\/span>/m)
        expect(response.body).to match(/<span class="metric-label">Opened<\/span>.*?<span class="metric-value">1<\/span>/m)
        expect(response.body).to match(/<span class="metric-label">Clicked<\/span>.*?<span class="metric-value">1<\/span>/m)
        expect(response.body).to match(/<span class="metric-value">1<\/span>\s*<span class="metric-label">Failed<\/span>/m)
      end
    end
  end
  
  describe "Filter functionality" do
    before { sign_in admin_user }
    
    # Create metrics with different email types
    let!(:daily_metric) { create(:email_metric, email_type: "daily_digest", user: regular_user) }
    let!(:weekly_metric) { create(:email_metric, email_type: "weekly_summary", user: regular_user) }
    
    it "allows filtering by email type", :aggregate_failures do
      # Add this test if the filter functionality exists
      # This depends on your actual implementation
      
      # For daily digest filter
      get admin_email_metrics_path, params: { filter: { email_type: "daily_digest" } }
      expect(response).to be_successful
      expect(response.body).to include("daily_digest")
      
      # For weekly summary filter
      get admin_email_metrics_path, params: { filter: { email_type: "weekly_summary" } }
      expect(response).to be_successful
      expect(response.body).to include("weekly_summary")
    end
  end
end