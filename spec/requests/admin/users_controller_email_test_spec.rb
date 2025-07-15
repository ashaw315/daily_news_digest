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
    
    # Mock the EnhancedNewsFetcher to avoid RSS calls
    allow_any_instance_of(EnhancedNewsFetcher).to receive(:fetch_articles).and_return([])
  end

  describe 'POST /admin/users/:id/send_test_email' do
    context 'when email delivery is successful' do
      it 'sends a test email and shows success message' do
        # Mock the mailer to track delivery
        mail_double = double('Mail::Message')
        allow(mail_double).to receive(:deliver_now).and_return(true)
        allow(DailyNewsMailer).to receive(:daily_digest).and_return(mail_double)
        
        post send_test_email_admin_user_path(test_user)
        
        expect(response).to redirect_to(admin_user_path(test_user))
        expect(flash[:notice]).to eq("Test email sent successfully to #{test_user.email}")
        expect(DailyNewsMailer).to have_received(:daily_digest).with(test_user, anything)
        expect(mail_double).to have_received(:deliver_now)
      end
    end

    context 'when email delivery fails' do
      it 'handles SMTP errors gracefully' do
        # Mock the mailer to raise an SMTP error
        mail_double = double('Mail::Message')
        allow(mail_double).to receive(:deliver_now).and_raise(Net::SMTPAuthenticationError.new('SMTP Authentication failed'))
        allow(DailyNewsMailer).to receive(:daily_digest).and_return(mail_double)
        
        post send_test_email_admin_user_path(test_user)
        
        expect(response).to redirect_to(admin_user_path(test_user))
        expect(flash[:alert]).to eq('Failed to send test email: SMTP Authentication failed')
      end
      
      it 'handles connection errors gracefully' do
        # Mock the mailer to raise a connection error
        mail_double = double('Mail::Message')
        allow(mail_double).to receive(:deliver_now).and_raise(Errno::ECONNREFUSED.new('Connection refused'))
        allow(DailyNewsMailer).to receive(:daily_digest).and_return(mail_double)
        
        post send_test_email_admin_user_path(test_user)
        
        expect(response).to redirect_to(admin_user_path(test_user))
        expect(flash[:alert]).to eq('Failed to send test email: Connection refused - Connection refused')
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
    it 'verifies mailer default from address' do
      expect(ApplicationMailer.default[:from]).to eq('news@dailynewsdigest.com')
    end
    
    it 'verifies daily news mailer from address' do
      expect(DailyNewsMailer.default[:from]).to eq('news@dailynewsdigest.com')
    end
  end
end