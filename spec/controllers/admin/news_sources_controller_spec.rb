require 'rails_helper'
require 'ostruct'

RSpec.describe Admin::NewsSourcesController, type: :controller do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, admin: true) }
  let(:news_source) { create(:news_source) }
  
  let(:valid_rss_response) {
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Hacker News</title>
          <link>https://news.ycombinator.com/</link>
          <description>Hacker News RSS</description>
          <item>
            <title>Test Article</title>
            <link>https://example.com/article1</link>
            <description>Test Description</description>
            <pubDate>#{Time.now.rfc2822}</pubDate>
          </item>
        </channel>
      </rss>
    XML
  }

  let(:valid_attributes) { 
    { 
      name: 'Hacker News', 
      url: 'https://hnrss.org/frontpage', 
      format: 'rss', 
      active: true,
      is_validated: 'true'
    } 
  }
  
  let(:invalid_attributes) { { name: '' } }

  before do
    # Stub HTTP requests
    stub_request(:get, "https://hnrss.org/frontpage")
      .with(
        headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Host'=>'hnrss.org',
          'User-Agent'=>'Ruby'
        }
      )
      .to_return(
        status: 200,
        body: valid_rss_response,
        headers: {'Content-Type' => 'application/rss+xml'}
      )

    # Mock the validator service
    validator_double = instance_double(SourceValidatorService)
    allow(validator_double).to receive(:validate).and_return(true)
    allow(validator_double).to receive(:errors).and_return([])
    allow(SourceValidatorService).to receive(:new).and_return(validator_double)
  end

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

  describe "PUT #update" do
    context "when signed in as admin" do
      before { sign_in admin_user }

      it "updates the news source" do
        patch :update, params: {
          id: news_source.id,
          news_source: valid_attributes
        }
        expect(response).to redirect_to(admin_news_source_path(news_source))
      end

      it "requires validation if URL changed" do
        patch :update, params: {
          id: news_source.id,
          news_source: valid_attributes.merge(
            url: 'https://new-url.com',
            is_validated: 'false'
          )
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE #destroy" do
    context "when signed in as admin" do
      before { sign_in admin_user }

      it "destroys the news source" do
        news_source_to_delete = create(:news_source)
        expect {
          delete :destroy, params: { id: news_source_to_delete.id }
        }.to change(NewsSource, :count).by(-1)
      end
    end
  end

  describe "POST #validate_new" do
    context "when signed in as admin" do
      before { sign_in admin_user }

      it "validates a new RSS feed URL" do
        post :validate_new, params: { 
          news_source: { url: 'https://hnrss.org/frontpage' } 
        }, format: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be true
        expect(json_response['message']).to eq("RSS feed validated successfully")
      end

      it "handles invalid RSS feed URLs" do
        # Override the validator double for this specific test
        validator_double = instance_double(SourceValidatorService)
        allow(validator_double).to receive(:validate).and_return(false)
        allow(validator_double).to receive(:errors).and_return(["Invalid RSS feed"])
        allow(SourceValidatorService).to receive(:new).and_return(validator_double)

        post :validate_new, params: { 
          news_source: { url: 'https://invalid-url.com' } 
        }, format: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be false
        expect(json_response['errors']).to be_present
      end
    end
  end

  describe "PATCH #validate" do
    context "when signed in as admin" do
      before { sign_in admin_user }

      it "validates an existing RSS feed URL" do
        patch :validate, params: { 
          id: news_source.id,
          news_source: { url: 'https://hnrss.org/frontpage' } 
        }, format: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be true
        expect(json_response['message']).to eq("RSS feed validated successfully")
      end
    end
  end
end