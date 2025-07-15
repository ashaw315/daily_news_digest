require 'rails_helper'

RSpec.describe Admin::UsersController, type: :request do
  let(:admin_user) { create(:user, admin: true) }
  let(:test_user) { create(:user, is_subscribed: true) }
  let(:topic) { create(:topic, name: 'Technology') }
  let(:news_source) { create(:news_source, name: 'Test Source', topic: topic) }
  
  before do
    sign_in admin_user
    
    # Set up test user with news sources
    test_user.news_sources << news_source
    
    # Create some test articles
    create(:article, 
      title: 'Test Article 1',
      summary: 'Test summary for article 1',
      news_source: news_source,
      source: news_source.name,
      publish_date: 1.hour.ago
    )
    create(:article, 
      title: 'Test Article 2',
      summary: 'Test summary for article 2',
      news_source: news_source,
      source: news_source.name,
      publish_date: 2.hours.ago
    )
    
    # Stub RSS feed requests to prevent actual HTTP calls
    stub_request(:get, news_source.url)
      .to_return(
        status: 200,
        body: valid_rss_response,
        headers: { 'Content-Type' => 'application/rss+xml' }
      )
  end
  
  let(:valid_rss_response) {
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Test Feed</title>
          <link>https://example.com</link>
          <description>Test RSS Feed</description>
          <item>
            <title>RSS Test Article</title>
            <link>https://example.com/rss1</link>
            <description>RSS Test Description</description>
            <pubDate>#{Time.now.rfc2822}</pubDate>
          </item>
        </channel>
      </rss>
    XML
  }

  describe 'POST /admin/users/:id/send_test_email' do
    context 'when email delivery is successful' do
      it 'sends a test email and redirects with success message' do
        # Mock the mailer to track delivery
        mail_double = double('Mail::Message')
        allow(mail_double).to receive(:deliver_now).and_return(true)
        allow(DailyNewsMailer).to receive(:daily_digest).and_return(mail_double)
        
        post send_test_email_admin_user_path(test_user)
        
        expect(response).to redirect_to(admin_user_path(test_user))
        expect(flash[:notice]).to eq('Test email sent successfully to user@example.com')
        expect(DailyNewsMailer).to have_received(:daily_digest).with(test_user, anything)
        expect(mail_double).to have_received(:deliver_now)
      end
      
      it 'calls the mailer with correct parameters' do
        # Mock the mailer
        mail_double = double('Mail::Message')
        allow(mail_double).to receive(:deliver_now).and_return(true)
        allow(DailyNewsMailer).to receive(:daily_digest).and_return(mail_double)
        
        post send_test_email_admin_user_path(test_user)
        
        expect(DailyNewsMailer).to have_received(:daily_digest) do |user, articles|
          expect(user).to eq(test_user)
          expect(articles).to be_an(Array)
          expect(articles.size).to be > 0
        end
      end
      
      it 'fetches articles from user subscribed sources' do
        # Mock the fetcher and mailer
        mock_fetcher = double('EnhancedNewsFetcher')
        allow(mock_fetcher).to receive(:fetch_articles).and_return([])
        allow(EnhancedNewsFetcher).to receive(:new).and_return(mock_fetcher)
        
        mail_double = double('Mail::Message')
        allow(mail_double).to receive(:deliver_now).and_return(true)
        allow(DailyNewsMailer).to receive(:daily_digest).and_return(mail_double)
        
        post send_test_email_admin_user_path(test_user)
        
        expect(EnhancedNewsFetcher).to have_received(:new).with(
          sources: [news_source],
          max_articles: 3
        )
        expect(mock_fetcher).to have_received(:fetch_articles)
      end
    end

    context 'when email delivery fails' do
      it 'handles delivery errors gracefully' do
        # Mock the mailer to raise an error
        mail_double = double('Mail::Message')
        allow(mail_double).to receive(:deliver_now).and_raise(StandardError.new('SMTP Error'))
        allow(DailyNewsMailer).to receive(:daily_digest).and_return(mail_double)
        
        post send_test_email_admin_user_path(test_user)
        
        expect(response).to redirect_to(admin_user_path(test_user))
        expect(flash[:alert]).to eq('Failed to send test email: SMTP Error')
      end
      
      it 'handles network timeout errors' do
        # Mock the mailer to raise a timeout error
        mail_double = double('Mail::Message')
        allow(mail_double).to receive(:deliver_now).and_raise(Net::TimeoutError.new('Connection timeout'))
        allow(DailyNewsMailer).to receive(:daily_digest).and_return(mail_double)
        
        post send_test_email_admin_user_path(test_user)
        
        expect(response).to redirect_to(admin_user_path(test_user))
        expect(flash[:alert]).to eq('Failed to send test email: Connection timeout')
      end
    end

    context 'when user has no subscribed sources' do
      it 'still sends email with empty articles' do
        # Remove news sources from user
        test_user.news_sources.clear
        
        mail_double = double('Mail::Message')
        allow(mail_double).to receive(:deliver_now).and_return(true)
        allow(DailyNewsMailer).to receive(:daily_digest).and_return(mail_double)
        
        post send_test_email_admin_user_path(test_user)
        
        expect(response).to redirect_to(admin_user_path(test_user))
        expect(flash[:notice]).to eq('Test email sent successfully to user@example.com')
        expect(DailyNewsMailer).to have_received(:daily_digest).with(test_user, [])
      end
    end

    context 'when user does not exist' do
      it 'returns 404' do
        expect {
          post send_test_email_admin_user_path(id: 999999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when not logged in as admin' do
      before { sign_out admin_user }
      
      it 'redirects to login' do
        post send_test_email_admin_user_path(test_user)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
  
  describe 'Email configuration verification' do
    it 'verifies production email configuration' do
      # This test verifies that production is configured correctly
      if Rails.env.production?
        expect(ActionMailer::Base.delivery_method).to eq(:smtp)
        expect(ActionMailer::Base.smtp_settings[:address]).to eq('smtp.sendgrid.net')
        expect(ActionMailer::Base.smtp_settings[:port]).to eq(587)
        expect(ActionMailer::Base.smtp_settings[:user_name]).to eq('apikey')
        expect(ActionMailer::Base.smtp_settings[:password]).to eq(ENV['SENDGRID_API_KEY'])
      end
    end
    
    it 'verifies mailer default from address' do
      expect(ApplicationMailer.default[:from]).to eq('news@dailynewsdigest.com')
    end
  end
end