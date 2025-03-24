require 'rails_helper'
require Rails.root.join('app/models/source')

RSpec.describe Admin::SourcesController, type: :request do
  let(:admin_user) { create(:user, admin: true) }
  let(:regular_user) { create(:user, admin: false) }
  let(:valid_attributes) {
    {
      name: "Test Source",
      url: "https://example.com/feed",
      source_type: "rss",
      active: true
    }
  }
  
  describe "GET /admin/sources" do
    context "when not logged in" do
      it "redirects to the login page" do
        get admin_sources_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
    
    context "when logged in as a regular user" do
      before { sign_in regular_user }
      
      it "redirects to the home page" do
        get admin_sources_path
        expect(response).to redirect_to(root_path)
      end
    end
    
    context "when logged in as an admin user" do
      before { sign_in admin_user }
      
      it "renders the index page" do
        get admin_sources_path
        expect(response).to be_successful
        expect(response.body).to include("Content Sources")
      end
    end
  end
  
  describe "POST /admin/sources" do
    context "when not logged in" do
      it "redirects to the login page" do
        post admin_sources_path, params: { source: valid_attributes }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
    
    context "when logged in as a regular user" do
      before { sign_in regular_user }
      
      it "redirects to the home page" do
        post admin_sources_path, params: { source: valid_attributes }
        expect(response).to redirect_to(root_path)
      end
    end
    
    context "when logged in as an admin user" do
      before { sign_in admin_user }
      
      it "creates a new source" do
        expect {
          post admin_sources_path, params: { source: valid_attributes }
        }.to change(Source, :count).by(1)
        
        expect(response).to redirect_to(admin_sources_path)
        expect(flash[:notice]).to eq("Source was successfully created.")
      end
    end
  end
  
  describe "DELETE /admin/sources/:id" do
    context "when not logged in" do
      let!(:source) { Source.create!(valid_attributes) }
      
      it "redirects to the login page" do
        delete admin_source_path(source)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
    
    context "when logged in as a regular user" do
      let!(:source) { Source.create!(valid_attributes) }
      before { sign_in regular_user }
      
      it "redirects to the home page" do
        delete admin_source_path(source)
        expect(response).to redirect_to(root_path)
      end
    end
    
    context "when logged in as an admin user" do
      let!(:source) { Source.create!(valid_attributes) }
      before { sign_in admin_user }
      
      it "destroys the source" do
        expect {
          delete admin_source_path(source)
        }.to change(Source, :count).by(-1)
        
        expect(response).to redirect_to(admin_sources_path)
        expect(flash[:notice]).to eq("Source was successfully destroyed.")
      end
    end
  end
end
