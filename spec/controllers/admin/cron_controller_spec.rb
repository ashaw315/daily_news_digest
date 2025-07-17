require 'rails_helper'

RSpec.describe Admin::CronController, type: :controller do
  let(:valid_api_key) { 'ab74ba512911b70ae162f4ec1cac9ad0' }
  let(:invalid_api_key) { 'invalid_key' }

  before do
    # Set the environment variable for API key validation
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('CRON_API_KEY').and_return(valid_api_key)
  end

  describe 'GET /health' do
    it 'returns health status without authentication' do
      get :health
      
      expect(response).to have_http_status(200)
      expect(response.content_type).to include('application/json')
      
      json_response = JSON.parse(response.body)
      expect(json_response['status']).to eq('ok')
      expect(json_response['timestamp']).to be_present
      expect(json_response['service']).to eq('daily-news-digest')
    end

    it 'responds quickly' do
      start_time = Time.current
      get :health
      end_time = Time.current
      
      expect(response).to have_http_status(200)
      expect(end_time - start_time).to be < 1.second
    end

    it 'does not require API key' do
      get :health
      
      expect(response).to have_http_status(200)
      json_response = JSON.parse(response.body)
      expect(json_response['status']).to eq('ok')
    end

    it 'includes proper timestamp format' do
      get :health
      
      json_response = JSON.parse(response.body)
      expect(json_response['timestamp']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
    end
  end

  describe 'Cron endpoints for GitHub Actions' do
    describe 'POST /admin/cron/purge_articles' do
      context 'with valid API key' do
        before do
          # Create some old articles to purge
          create(:article, created_at: 25.hours.ago)
          create(:article, created_at: 23.hours.ago) # Should not be purged
        end

        it 'accepts requests from GitHub Actions' do
          post :purge_articles, params: { api_key: valid_api_key }
          
          expect(response).to have_http_status(200)
          json_response = JSON.parse(response.body)
          expect(json_response['status']).to eq('success')
          expect(json_response['message']).to include('Successfully deleted')
        end

        it 'completes within timeout limits' do
          start_time = Time.current
          post :purge_articles, params: { api_key: valid_api_key }
          end_time = Time.current
          
          expect(response).to have_http_status(200)
          expect(end_time - start_time).to be < 5.minutes
        end

        it 'logs the request properly' do
          allow(Rails.logger).to receive(:info).and_call_original
          expect(Rails.logger).to receive(:info).with(/CRON.*Job triggered: purge_articles/)
          expect(Rails.logger).to receive(:info).with(/CRON.*User Agent:/)
          expect(Rails.logger).to receive(:info).with(/CRON.*IP:/)
          expect(Rails.logger).to receive(:info).with(/CRON.*Method: POST/)
          
          post :purge_articles, params: { api_key: valid_api_key }
        end

        it 'purges articles older than 24 hours' do
          expect {
            post :purge_articles, params: { api_key: valid_api_key }
          }.to change { Article.count }.by(-1) # Only the 25-hour-old article should be deleted
        end
      end

      context 'with invalid API key' do
        it 'returns unauthorized status' do
          post :purge_articles, params: { api_key: invalid_api_key }
          
          expect(response).to have_http_status(401)
        end
      end

      context 'without API key' do
        it 'returns unauthorized status' do
          post :purge_articles
          
          expect(response).to have_http_status(401)
        end
      end
    end

    describe 'POST /admin/cron/fetch_articles' do
      context 'with valid API key' do
        before do
          # Create test news sources and users
          user = create(:user, is_subscribed: true)
          news_source = create(:news_source, active: true, url: 'https://example.com/rss')
          user.news_sources << news_source
        end

        it 'accepts requests from GitHub Actions' do
          # Mock the article fetcher to avoid external HTTP calls
          allow_any_instance_of(EnhancedNewsFetcher).to receive(:fetch_articles).and_return([])
          
          post :fetch_articles, params: { api_key: valid_api_key }
          
          expect(response).to have_http_status(200)
          json_response = JSON.parse(response.body)
          expect(json_response['status']).to eq('success')
          expect(json_response['message']).to include('Fetched')
        end

        it 'completes within timeout limits' do
          # Mock the article fetcher to respond quickly
          allow_any_instance_of(EnhancedNewsFetcher).to receive(:fetch_articles).and_return([])
          
          start_time = Time.current
          post :fetch_articles, params: { api_key: valid_api_key }
          end_time = Time.current
          
          expect(response).to have_http_status(200)
          expect(end_time - start_time).to be < 5.minutes
        end

        it 'handles no active sources gracefully' do
          # Remove all news sources
          NewsSource.destroy_all
          
          post :fetch_articles, params: { api_key: valid_api_key }
          
          expect(response).to have_http_status(200)
          json_response = JSON.parse(response.body)
          expect(json_response['message']).to include('No active sources')
        end
      end

      context 'with invalid API key' do
        it 'returns unauthorized status' do
          post :fetch_articles, params: { api_key: invalid_api_key }
          
          expect(response).to have_http_status(401)
        end
      end
    end

    describe 'POST /admin/cron/schedule_daily_emails' do
      context 'with valid API key' do
        before do
          # Create required seed data for user callbacks
          create(:topic, name: 'Technology', active: true)
          create(:topic, name: 'Business', active: true) 
          create(:topic, name: 'Politics', active: true)
          create(:news_source, name: 'Test Source', active: true)
          
          # Create users with daily email preferences
          user1 = create(:user, is_subscribed: true)
          user1.preferences.update!(email_frequency: 'daily')
          
          user2 = create(:user, is_subscribed: false) # Should be ignored
          user2.preferences.update!(email_frequency: 'daily')
          
          user3 = create(:user, is_subscribed: true) # Should be ignored
          user3.preferences.update!(email_frequency: 'weekly')
        end

        it 'accepts requests from GitHub Actions' do
          # Mock the job to avoid actual email scheduling
          allow(DailyEmailJob).to receive(:perform_later)
          
          post :schedule_daily_emails, params: { api_key: valid_api_key }
          
          expect(response).to have_http_status(200)
          json_response = JSON.parse(response.body)
          expect(json_response['status']).to eq('success')
          expect(json_response['message']).to include('Daily emails scheduled for 1 users')
        end

        it 'completes within timeout limits' do
          allow(DailyEmailJob).to receive(:perform_later)
          
          start_time = Time.current
          post :schedule_daily_emails, params: { api_key: valid_api_key }
          end_time = Time.current
          
          expect(response).to have_http_status(200)
          expect(end_time - start_time).to be < 5.minutes
        end

        it 'handles no users gracefully' do
          # Remove all users properly (preferences will be deleted via dependent: :destroy)
          User.joins(:preferences).where('preferences.email_frequency = ?', 'daily').destroy_all
          
          post :schedule_daily_emails, params: { api_key: valid_api_key }
          
          expect(response).to have_http_status(200)
          json_response = JSON.parse(response.body)
          expect(json_response['message']).to include('No users to process')
        end

        it 'schedules jobs for eligible users only' do
          expect(DailyEmailJob).to receive(:perform_later).exactly(1).times # Only 1 eligible user
          
          post :schedule_daily_emails, params: { api_key: valid_api_key }
        end
      end

      context 'with invalid API key' do
        it 'returns unauthorized status' do
          post :schedule_daily_emails, params: { api_key: invalid_api_key }
          
          expect(response).to have_http_status(401)
        end
      end
    end
  end

  describe 'Error handling and resilience' do
    it 'handles database errors gracefully in purge_articles' do
      allow(Article).to receive(:where).and_raise(StandardError.new('Database error'))
      
      post :purge_articles, params: { api_key: valid_api_key }
      
      expect(response).to have_http_status(500)
      json_response = JSON.parse(response.body)
      expect(json_response['status']).to eq('error')
    end

    it 'handles errors gracefully in fetch_articles' do
      allow(NewsSource).to receive(:joins).and_raise(StandardError.new('Database error'))
      
      post :fetch_articles, params: { api_key: valid_api_key }
      
      expect(response).to have_http_status(500)
      json_response = JSON.parse(response.body)
      expect(json_response['status']).to eq('error')
    end

    it 'handles errors gracefully in schedule_daily_emails' do
      allow(User).to receive(:joins).and_raise(StandardError.new('Database error'))
      
      post :schedule_daily_emails, params: { api_key: valid_api_key }
      
      expect(response).to have_http_status(500)
      json_response = JSON.parse(response.body)
      expect(json_response['status']).to eq('error')
    end
  end

  describe 'Task locking' do
    it 'prevents concurrent execution of fetch_articles' do
      # Mock Rails cache to simulate lock exists
      allow(Rails.cache).to receive(:exist?).with('cron_lock:fetch_articles').and_return(true)
      
      post :fetch_articles, params: { api_key: valid_api_key }
      
      expect(response).to have_http_status(409) # Conflict
      json_response = JSON.parse(response.body)
      expect(json_response['message']).to include('already running')
    end

    it 'prevents concurrent execution of schedule_daily_emails' do
      # Mock Rails cache to simulate lock exists
      allow(Rails.cache).to receive(:exist?).with('cron_lock:schedule_daily_emails').and_return(true)
      
      post :schedule_daily_emails, params: { api_key: valid_api_key }
      
      expect(response).to have_http_status(409) # Conflict
      json_response = JSON.parse(response.body)
      expect(json_response['message']).to include('already running')
    end
  end

  describe 'Authentication' do
    it 'accepts API key in header' do
      request.headers['X-API-KEY'] = valid_api_key
      
      post :purge_articles
      
      expect(response).to have_http_status(200)
    end

    it 'accepts API key as parameter' do
      post :purge_articles, params: { api_key: valid_api_key }
      
      expect(response).to have_http_status(200)
    end

    it 'rejects invalid API key in header' do
      request.headers['X-API-KEY'] = invalid_api_key
      
      post :purge_articles
      
      expect(response).to have_http_status(401)
    end

    it 'compares API keys securely' do
      expect(ActiveSupport::SecurityUtils).to receive(:secure_compare)
        .with(valid_api_key, valid_api_key)
        .and_return(true)
      
      post :purge_articles, params: { api_key: valid_api_key }
      
      expect(response).to have_http_status(200)
    end
  end
end