require 'rails_helper'

RSpec.describe Admin::NewsSourcesController, type: :request do
  let(:admin_user) { create(:user, admin: true) }
  let(:regular_user) { create(:user, admin: false) }
  let(:news_source) { create(:news_source) }
  let(:valid_attributes) {
    {
      name: "Test Source",
      url: "https://example.com/feed",
      format: "rss",
      active: true,
      is_validated: "true"
    }
  }
  
  describe "GET /admin/news_sources" do
    context "when not logged in" do
      it "redirects to the login page" do
        get admin_news_sources_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
    
    context "when logged in as a regular user" do
      before { sign_in regular_user }
      
      it "redirects to the home page" do
        get admin_news_sources_path
        expect(response).to redirect_to(root_path)
      end
    end
    
    context "when logged in as an admin user" do
      before { sign_in admin_user }
      
      it "renders the index page" do
        get admin_news_sources_path
        expect(response).to be_successful
        expect(response.body).to include("News Sources")
      end
    end
  end
  
  describe "GET /admin/news_sources/new" do
    context "when logged in as an admin user" do
      before { sign_in admin_user }
      
      it "renders the new form" do
        get new_admin_news_source_path
        expect(response).to be_successful
        expect(response.body).to include("New News Source")
      end
    end
  end
  
  describe "GET /admin/news_sources/:id/edit" do
    context "when logged in as an admin user" do
      before { sign_in admin_user }
      
      it "renders the edit form" do
        get edit_admin_news_source_path(news_source)
        expect(response).to be_successful
        expect(response.body).to include("Edit News Source")
        expect(response.body).to include('input type="submit" name="commit" value="Update News source"')
        expect(response.body).to include('id="validate-source"')
      end
    end
  end
  
  describe "POST /admin/news_sources" do
    context "when not logged in" do
      it "redirects to the login page" do
        post admin_news_sources_path, params: { news_source: valid_attributes }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
    
    context "when logged in as a regular user" do
      before { sign_in regular_user }
      
      it "redirects to the home page" do
        post admin_news_sources_path, params: { news_source: valid_attributes }
        expect(response).to redirect_to(root_path)
      end
    end
    
    context "when logged in as an admin user" do
      before { 
        sign_in admin_user
        # Mock the validation to always return true
        allow_any_instance_of(SourceValidatorService).to receive(:validate).and_return(true)
      }
      
      it "creates a new source with validation" do
        expect {
          post admin_news_sources_path, params: { news_source: valid_attributes }
        }.to change(NewsSource, :count).by(1)
        
        expect(response).to redirect_to(admin_news_source_path(NewsSource.last))
        expect(flash[:notice]).to eq("News source was successfully created.")
      end
      
      it "doesn't create a source without validation" do
        expect {
          post admin_news_sources_path, params: { 
            news_source: valid_attributes.merge(is_validated: "false") 
          }
        }.not_to change(NewsSource, :count)
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(flash[:alert]).to match(/Please validate the RSS feed/)
      end
    end
  end
  
  describe "PUT /admin/news_sources/:id" do
    context "when logged in as an admin user" do
      before { 
        sign_in admin_user
        # Mock the validation to always return true
        allow_any_instance_of(SourceValidatorService).to receive(:validate).and_return(true)
      }
      
      it "updates the source" do
        put admin_news_source_path(news_source), params: { 
          news_source: { name: "Updated Name", is_validated: "true" }
        }
        
        news_source.reload
        expect(news_source.name).to eq("Updated Name")
        expect(response).to redirect_to(admin_news_source_path(news_source))
      end
      
      it "requires validation if URL changed" do
        put admin_news_source_path(news_source), params: { 
          news_source: { url: "https://new-url.com", is_validated: "false" }
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(flash[:alert]).to match(/You've changed the URL/)
      end
    end
  end
  
  describe "DELETE /admin/news_sources/:id" do
    context "when not logged in" do
      it "redirects to the login page" do
        delete admin_news_source_path(news_source)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
    
    context "when logged in as a regular user" do
      before { sign_in regular_user }
      
      it "redirects to the home page" do
        delete admin_news_source_path(news_source)
        expect(response).to redirect_to(root_path)
      end
    end
    
    context "when logged in as an admin user" do
      before { sign_in admin_user }
      
      it "destroys the source when not in use" do
        # Mock in_use? to return false
        allow_any_instance_of(NewsSource).to receive(:in_use?).and_return(false)
        
        delete admin_news_source_path(news_source)
        expect(response).to redirect_to(admin_news_sources_path)
        expect(flash[:notice]).to eq("News source was successfully destroyed.")
      end
      
      it "doesn't destroy the source when in use" do
        # Mock in_use? to return true
        allow_any_instance_of(NewsSource).to receive(:in_use?).and_return(true)
        
        delete admin_news_source_path(news_source)
        expect(response).to redirect_to(admin_news_sources_path)
        expect(flash[:alert]).to match(/Cannot delete a news source that is in use/)
      end
    end
  end
  
  describe "POST /admin/news_sources/validate_new" do
    context "when logged in as an admin user" do
      before { sign_in admin_user }
      
      it "validates a new RSS feed URL" do
        # Mock the validation service
        allow_any_instance_of(NewsSource).to receive(:validate_source).and_return(true)
        
        post validate_new_admin_news_sources_path, params: { 
          news_source: { url: "https://example.com/feed" }
        }, as: :json
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be true
        expect(json_response['message']).to eq("RSS feed validated successfully")
      end
      
      it "handles invalid RSS feed URLs" do
        # Mock the validation service to return errors
        allow_any_instance_of(NewsSource).to receive(:validate_source).and_return(["Invalid RSS feed"])
        
        post validate_new_admin_news_sources_path, params: { 
          news_source: { url: "https://invalid-url.com" }
        }, as: :json
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be false
        expect(json_response['errors']).to include("Invalid RSS feed")
      end
    end
  end
  
  describe "PATCH /admin/news_sources/:id/validate" do
    context "when logged in as an admin user" do
      before { sign_in admin_user }
      
      it "validates an existing RSS feed URL" do
        # Mock the validation service
        allow_any_instance_of(NewsSource).to receive(:validate_source).and_return(true)
        
        patch validate_admin_news_source_path(news_source), params: { 
          news_source: { url: "https://example.com/updated-feed" }
        }, as: :json
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be true
        expect(json_response['message']).to eq("RSS feed validated successfully")
      end
    end
  end
  
  describe "GET /admin/news_sources/:id/preview" do
    context "when logged in as an admin user" do
      before { 
        sign_in admin_user
        
        # Mock the fetcher to return sample articles
        allow_any_instance_of(NewsFetcher).to receive(:fetch_articles).and_return([
          { title: "Article 1", url: "https://example.com/1", content: "Content 1", description: "Description 1" },
          { title: "Article 2", url: "https://example.com/2", content: "Content 2", description: "Description 2" }
        ])
      }
      
      it "shows a preview of articles from the source" do
        get preview_admin_news_source_path(news_source)
        
        expect(response).to be_successful
        expect(response.body).to include("Preview")
      end
      
      it "returns JSON when requested" do
        get preview_admin_news_source_path(news_source, format: :json)
        
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("application/json")
        json_response = JSON.parse(response.body)
        expect(json_response.length).to eq(2)
        expect(json_response[0]["title"]).to eq("Article 1")
      end
    end
  end
end