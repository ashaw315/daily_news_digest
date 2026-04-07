require 'rails_helper'

RSpec.describe Admin::CronController, 'task locking', type: :request do
  let(:api_key) { 'test-cron-api-key' }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('CRON_API_KEY').and_return(api_key)

    # Use memory_store so cache operations actually persist within the test
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  after do
    Rails.cache = @original_cache
  end

  describe 'POST /admin/cron/fetch_articles (lock behavior)' do
    it 'returns 409 when a lock is already held' do
      Rails.cache.write('cron_lock:fetch_articles', true, expires_in: 30.minutes)

      post admin_cron_fetch_articles_path,
           headers: { 'X-API-KEY' => api_key }

      expect(response).to have_http_status(:conflict)
      parsed = JSON.parse(response.body)
      expect(parsed['status']).to eq('error')
      expect(parsed['message']).to include('already running')
    end

    it 'clears the cache key after a successful run' do
      # Create the minimum data to let fetch_articles succeed quickly
      post admin_cron_fetch_articles_path,
           headers: { 'X-API-KEY' => api_key }

      expect(response).to have_http_status(:ok)
      expect(Rails.cache.exist?('cron_lock:fetch_articles')).to be false
    end
  end

  describe 'POST /admin/cron/schedule_daily_emails (lock behavior)' do
    it 'returns 409 when a lock is already held' do
      Rails.cache.write('cron_lock:schedule_daily_emails', true, expires_in: 30.minutes)

      post admin_cron_schedule_daily_emails_path,
           headers: { 'X-API-KEY' => api_key }

      expect(response).to have_http_status(:conflict)
      parsed = JSON.parse(response.body)
      expect(parsed['message']).to include('already running')
    end

    it 'clears the cache key after a successful run' do
      post admin_cron_schedule_daily_emails_path,
           headers: { 'X-API-KEY' => api_key }

      expect(response).to have_http_status(:ok)
      expect(Rails.cache.exist?('cron_lock:schedule_daily_emails')).to be false
    end
  end
end
