require 'rails_helper'
require Rails.root.join('app/models/source')

RSpec.describe Admin::NewsSourcesController, type: :request do
  let(:admin_user) { create(:user, admin: true) }
  let(:regular_user) { create(:user, admin: false) }
  let(:valid_attributes) {
    {
      name: "Test Source",
      url: "https://example.com/feed",
      format: "rss",
      active: true
    }
  }
  
  describe "GET /admin/sources" do
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
  
  describe "POST /admin/news_sources" do  # Updated path
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
      before { sign_in admin_user }
      
      it "creates a new source" do
        expect {
          post admin_news_sources_path, params: { news_source: valid_attributes }  # Changed from source to news_source
        }.to change(NewsSource, :count).by(1)  # Changed from Source to NewsSource
        
        expect(response).to redirect_to(admin_news_source_path(NewsSource.last))
        expect(flash[:notice]).to eq("News source was successfully created.")
      end
    end
  end
  
  describe "DELETE /admin/sources/:id" do
    context "when not logged in" do
      let!(:source) { NewsSource.create!(valid_attributes) }
      
      it "redirects to the login page" do
        delete admin_news_source_path(source)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
    
    context "when logged in as a regular user" do
      let!(:source) { NewsSource.create!(valid_attributes) }
      before { sign_in regular_user }
      
      it "redirects to the home page" do
        delete admin_news_source_path(source)
        expect(response).to redirect_to(root_path)
      end
    end
    
    context "when logged in as an admin user" do
      let!(:source) { NewsSource.create!(valid_attributes) }
      before { sign_in admin_user }
      
      it "destroys the source" do
        expect {
          delete admin_news_source_path(source)
        }.to change(NewsSource, :count).by(-1)
        
        expect(response).to redirect_to(admin_news_sources_path)
        expect(flash[:notice]).to eq("News source was successfully destroyed.")
      end
    end
  end
end
