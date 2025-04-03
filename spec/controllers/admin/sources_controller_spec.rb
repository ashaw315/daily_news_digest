require 'rails_helper'

RSpec.describe Admin::SourcesController, type: :controller do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, admin: true) }
  let(:source) { create(:news_source) }
  let(:valid_attributes) { { name: 'New Source', url: 'https://example.com', format: 'api', active: true } }
  let(:invalid_attributes) { { name: '' } }

  describe "GET #index" do
    context "when signed in as admin" do
      before { sign_in admin_user }

      it "returns success" do
        get :index
        expect(response).to have_http_status(:success)
      end

      it "assigns all sources" do
        source # Create the source
        get :index
        expect(assigns(:sources)).to include(source)
      end
    end
  end

  # Similar tests as for TopicsController for show, new, edit, create, update, destroy
end