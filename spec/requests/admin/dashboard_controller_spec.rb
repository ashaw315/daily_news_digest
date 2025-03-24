require 'rails_helper'

RSpec.describe Admin::DashboardController, type: :request do
  let(:admin_user) { create(:user, admin: true) }
  let(:regular_user) { create(:user, admin: false) }
  
  describe "GET /admin/dashboard" do
    context "when not logged in" do
      it "redirects to the login page" do
        get admin_dashboard_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
    
    context "when logged in as a regular user" do
      before { sign_in regular_user }
      
      it "redirects to the home page" do
        get admin_dashboard_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to access this area.")
      end
    end
    
    context "when logged in as an admin user" do
      before { sign_in admin_user }
      
      it "renders the dashboard" do
        get admin_dashboard_path
        expect(response).to be_successful
        expect(response.body).to include("Admin Dashboard")
      end
    end
  end
end 