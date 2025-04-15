require 'rails_helper'

RSpec.describe Admin::NewsSourcesController, type: :controller do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, admin: true) }
  let(:news_source) { create(:news_source) }
  let(:valid_attributes) { 
    { 
      name: 'Hacker News', 
      url: 'https://hnrss.org/frontpage', 
      format: 'rss', 
      active: true,
      is_validated: 'true'  # Add this
    } 
  }
  let(:invalid_attributes) { { name: '' } }

  describe "GET #index" do
    context "when not signed in" do
      it "redirects to login page" do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in as regular user" do
      before { sign_in user }

      it "redirects to root" do
        get :index
        expect(response).to redirect_to(root_path)
      end
    end

    context "when signed in as admin" do
      before { sign_in admin_user }

      it "returns success" do
        get :index
        expect(response).to have_http_status(:success)
      end

      it "assigns all news sources" do
        news_source # Create the news source
        get :index
        expect(assigns(:sources)).to include(news_source)
      end
    end
  end

  describe "GET #show" do
    context "when signed in as admin" do
      before { sign_in admin_user }

      it "returns success" do
        get :show, params: { id: news_source.id }
        expect(response).to have_http_status(:success)
      end

      it "assigns the requested news source" do
        get :show, params: { id: news_source.id }
        expect(assigns(:source)).to eq(news_source)
      end
    end
  end

  describe "GET #new" do
    context "when signed in as admin" do
      before { sign_in admin_user }

      it "returns success" do
        get :new
        expect(response).to have_http_status(:success)
      end

      it "assigns a new news source" do
        get :new
        expect(assigns(:source)).to be_a_new(NewsSource)
      end
    end
  end

  describe "GET #edit" do
    context "when signed in as admin" do
      before { sign_in admin_user }

      it "returns success" do
        get :edit, params: { id: news_source.id }
        expect(response).to have_http_status(:success)
      end

      it "assigns the requested news source" do
        get :edit, params: { id: news_source.id }
        expect(assigns(:source)).to eq(news_source)
      end
    end
  end

  describe "POST #create" do
    context "when signed in as admin" do
      before { sign_in admin_user }

      context "with valid params" do
        before do
          # Mock the validation service to return success
          allow_any_instance_of(NewsSource).to receive(:validate_source).and_return(true)
        end

        it "creates a new news source" do
          expect {
            post :create, params: { news_source: valid_attributes }
          }.to change(NewsSource, :count).by(1)
        end

        it "redirects to the created news source" do
          post :create, params: { news_source: valid_attributes }
          expect(response).to redirect_to(admin_news_source_path(NewsSource.last))
        end
      end

      context "with invalid params" do
        it "does not create a new news source" do
          expect {
            post :create, params: { news_source: invalid_attributes }
          }.not_to change(NewsSource, :count)
        end

        it "returns unprocessable entity status" do
          post :create, params: { news_source: invalid_attributes }
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context "without validation" do
        it "does not create a news source without validation" do
          expect {
            post :create, params: { 
              news_source: valid_attributes.merge(is_validated: 'false') 
            }
          }.not_to change(NewsSource, :count)
        end

        it "returns unprocessable entity status when not validated" do
          post :create, params: { 
            news_source: valid_attributes.merge(is_validated: 'false') 
          }
          expect(response).to have_http_status(:unprocessable_entity)
          expect(flash[:alert]).to match(/Please validate the RSS feed/)
        end
      end
    end
  end

  describe "POST #validate" do
    context "when signed in as admin" do
      before { sign_in admin_user }

      it "validates a new RSS feed URL" do
        # Mock the validation service
        allow_any_instance_of(NewsSource).to receive(:validate_source).and_return(true)

        binding.pry
        
        post :validate, params: { 
          news_source: { url: 'https://hnrss.org/frontpage' } 
        }, format: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be true
        expect(json_response['message']).to eq("RSS feed validated successfully")
      end

      it "handles invalid RSS feed URLs" do
        # Mock the validation service to return error
        allow_any_instance_of(NewsSource).to receive(:validate_source).and_return(["Invalid RSS feed"])
        
        post :validate, params: { 
          news_source: { url: 'https://invalid-url.com' } 
        }, format: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be false
        expect(json_response['errors']).to be_present
      end
    end
  end
end