require 'rails_helper'

RSpec.describe Admin::EmailMetricsController, type: :request do
  let(:admin_user) { create(:user, admin: true) }
  let(:regular_user) { create(:user, admin: false) }
  
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
    end
  end
end 