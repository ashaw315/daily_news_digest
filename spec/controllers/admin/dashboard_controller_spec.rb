require 'rails_helper'

RSpec.describe Admin::DashboardController, type: :controller do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, admin: true) }

  describe "GET #index" do
    context "when not signed in" do
      it "redirects to login page" do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in as regular user" do
      before { sign_in user }

      it "returns redirect status" do
        get :index
        expect(response).to have_http_status(:found) # 302 redirect
        expect(response).to be_redirect
      end
    end

    context "when signed in as admin" do
      before { sign_in admin_user }

      it "returns success" do
        get :index
        expect(response).to have_http_status(:success)
      end

      it "renders the index template" do
        get :index
        expect(response).to render_template(:index)
      end

      it "assigns dashboard stats" do
        get :index
        expect(assigns(:user_count)).to be_a(Integer)
        expect(assigns(:article_count)).to be_a(Integer)  # Changed from topic_count
        expect(assigns(:source_count)).to be_a(Integer)
        expect(assigns(:email_metrics)).not_to be_nil
      end
    end
  end
end