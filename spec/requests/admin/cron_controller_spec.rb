require 'rails_helper'

RSpec.describe Admin::CronController, type: :request do
  let(:api_key) { 'test-cron-api-key' }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('CRON_API_KEY').and_return(api_key)
  end

  shared_examples 'cron endpoint authentication' do |endpoint_path_helper|
    it 'returns success with a valid API key' do
      post send(endpoint_path_helper), headers: { 'X-API-KEY' => api_key }

      expect(response).to have_http_status(:ok)
      parsed = JSON.parse(response.body)
      expect(parsed['status']).to eq('success')
    end

    it 'returns 401 without an API key' do
      post send(endpoint_path_helper)

      expect(response).to have_http_status(:unauthorized)
      parsed = JSON.parse(response.body)
      expect(parsed['status']).to eq('error')
      expect(parsed['message']).to include('API key required')
    end

    it 'returns 401 with an invalid API key' do
      post send(endpoint_path_helper), headers: { 'X-API-KEY' => 'wrong-key' }

      expect(response).to have_http_status(:unauthorized)
      parsed = JSON.parse(response.body)
      expect(parsed['status']).to eq('error')
      expect(parsed['message']).to include('Unauthorized')
    end
  end

  describe 'POST /admin/cron/fetch_articles' do
    before do
      fetcher = instance_double(EnhancedNewsFetcher, fetch_articles: [])
      allow(EnhancedNewsFetcher).to receive(:new).and_return(fetcher)
    end

    it_behaves_like 'cron endpoint authentication', :admin_cron_fetch_articles_path
  end

  describe 'POST /admin/cron/schedule_daily_emails' do
    it_behaves_like 'cron endpoint authentication', :admin_cron_schedule_daily_emails_path
  end

  describe 'POST /admin/cron/purge_articles' do
    it_behaves_like 'cron endpoint authentication', :admin_cron_purge_articles_path
  end
end
