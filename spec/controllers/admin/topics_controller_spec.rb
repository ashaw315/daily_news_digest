require 'rails_helper'

RSpec.describe Admin::TopicsController, type: :controller do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, admin: true) }
  let(:topic) { create(:topic) }
  let(:valid_attributes) { { name: 'New Topic' } }
  let(:invalid_attributes) { { name: '' } }

  describe "GET #index" do
    context "when signed in as admin" do
      before { sign_in admin_user }

      it "returns success" do
        get :index
        expect(response).to have_http_status(:success)
      end

      it "assigns all topics" do
        topic # Create the topic
        get :index
        expect(assigns(:topics)).to include(topic)
      end
    end
  end

  describe "GET #show" do
    context "when signed in as admin" do
      before { sign_in admin_user }

      it "returns success" do
        get :show, params: { id: topic.id }
        expect(response).to have_http_status(:success)
      end

      it "assigns the requested topic" do
        get :show, params: { id: topic.id }
        expect(assigns(:topic)).to eq(topic)
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

      it "assigns a new topic" do
        get :new
        expect(assigns(:topic)).to be_a_new(Topic)
      end
    end
  end

  describe "GET #edit" do
    context "when signed in as admin" do
      before { sign_in admin_user }

      it "returns success" do
        get :edit, params: { id: topic.id }
        expect(response).to have_http_status(:success)
      end

      it "assigns the requested topic" do
        get :edit, params: { id: topic.id }
        expect(assigns(:topic)).to eq(topic)
      end
    end
  end

  describe "POST #create" do
    context "when signed in as admin" do
      before { sign_in admin_user }

      context "with valid params" do
        it "creates a new Topic" do
          expect {
            post :create, params: { topic: valid_attributes }
          }.to change(Topic, :count).by(1)
        end

        it "redirects to the created topic" do
          post :create, params: { topic: valid_attributes }
          expect(response).to redirect_to(admin_topic_path(Topic.last))
        end
      end

      context "with invalid params" do
        it "does not create a new Topic" do
          expect {
            post :create, params: { topic: invalid_attributes }
          }.not_to change(Topic, :count)
        end

        it "returns unprocessable entity status" do
          post :create, params: { topic: invalid_attributes }
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end
  end

  describe "PATCH #update" do
    context "when signed in as admin" do
      before { sign_in admin_user }

      context "with valid params" do
        let(:new_attributes) { { name: 'Updated Topic' } }

        it "updates the requested topic" do
          patch :update, params: { id: topic.id, topic: new_attributes }
          topic.reload
          expect(topic.name).to eq('Updated Topic')
        end

        it "redirects to the topic" do
          patch :update, params: { id: topic.id, topic: new_attributes }
          expect(response).to redirect_to(admin_topic_path(topic))
        end
      end

      context "with invalid params" do
        it "does not update the topic" do
          original_name = topic.name
          patch :update, params: { id: topic.id, topic: invalid_attributes }
          topic.reload
          expect(topic.name).to eq(original_name)
        end

        it "returns unprocessable entity status" do
          patch :update, params: { id: topic.id, topic: invalid_attributes }
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end
  end

  describe "DELETE #destroy" do
    context "when signed in as admin" do
      before { sign_in admin_user }

      it "destroys the requested topic" do
        topic # Create the topic
        expect {
          delete :destroy, params: { id: topic.id }
        }.to change(Topic, :count).by(-1)
      end

      it "redirects to the topics list" do
        delete :destroy, params: { id: topic.id }
        expect(response).to redirect_to(admin_topics_path)
      end
    end
  end
end