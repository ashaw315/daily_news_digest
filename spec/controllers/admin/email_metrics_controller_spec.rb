require 'rails_helper'

RSpec.describe Admin::EmailMetricsController, type: :controller do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, admin: true) }
  let!(:email_metric) { create(:email_metric, user: user) }

  describe "GET #index" do
    context "when signed in as admin" do
      before { sign_in admin_user }

      it "returns success" do
        get :index
        expect(response).to have_http_status(:success)
      end

      it "assigns all email metrics" do
        get :index
        expect(assigns(:email_metrics)).to include(email_metric)
      end
    end
  end
end