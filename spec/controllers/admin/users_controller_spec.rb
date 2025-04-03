require 'rails_helper'

RSpec.describe Admin::UsersController, type: :controller do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, admin: true) }

  describe "GET #index" do
    context "when signed in as admin" do
      before { sign_in admin_user }

      it "returns success" do
        get :index
        expect(response).to have_http_status(:success)
      end

      it "assigns all users" do
        get :index
        expect(assigns(:users)).to include(user)
        expect(assigns(:users)).to include(admin_user)
      end
    end
  end

  describe "GET #show" do
    context "when signed in as admin" do
      before { sign_in admin_user }

      it "returns success" do
        get :show, params: { id: user.id }
        expect(response).to have_http_status(:success)
      end

      it "assigns the requested user" do
        get :show, params: { id: user.id }
        expect(assigns(:user)).to eq(user)
      end
    end
  end
end