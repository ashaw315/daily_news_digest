require 'rails_helper'

RSpec.describe SubscriptionsController, type: :controller do
  describe 'GET #unsubscribe' do
    context 'with a valid token' do
      let(:user) { create(:user, is_subscribed: true) }
      
      before do
        get :unsubscribe, params: { token: user.unsubscribe_token }
        user.reload
      end
      
      it 'unsubscribes the user' do
        expect(user.is_subscribed).to be false
      end
      
      it 'sets a success flash message' do
        expect(flash[:notice]).to eq('You have been successfully unsubscribed from our emails.')
      end
      
      it 'redirects to the root path' do
        expect(response).to redirect_to(root_path)
      end
    end
    
    context 'with an invalid token' do
      before do
        get :unsubscribe, params: { token: 'invalid-token' }
      end
      
      it 'sets an error flash message' do
        expect(flash[:alert]).to eq('Invalid unsubscribe token.')
      end
      
      it 'redirects to the root path' do
        expect(response).to redirect_to(root_path)
      end
    end
  end
end 