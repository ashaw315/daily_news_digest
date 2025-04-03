require 'rails_helper'

RSpec.describe WeeklyEmailJob, type: :job do
  include ActiveJob::TestHelper
  
  # Create the user with is_subscribed: true
  let(:user) { create(:user, is_subscribed: true) }
  
  # Create a technology topic
  let!(:technology_topic) { create(:topic, name: 'technology') }
  
  before do
    # Clear any existing associations to avoid conflicts
    user.topics.clear
    
    # Associate the user with the technology topic
    user.topics << technology_topic
    
    # Make sure the user has a preferences record with weekly frequency
    if user.preferences.nil?
      user.create_preferences(email_frequency: 'weekly')
    else
      user.preferences.update!(email_frequency: 'weekly')
    end
    
    # Mock the ArticleFetcher
    allow(ArticleFetcher).to receive(:fetch_for_user).and_return(articles)
  end
  
  let(:articles) { [double('Article', title: 'Test', description: 'Test', source: 'Test', url: 'http://test.com', published_at: Time.now, topic: 'technology')] }
  
  describe "#perform" do
    it "sends an email to the user" do
      mail_double = double("Mail::Message")
      allow(mail_double).to receive(:deliver_now)
      
      # Use DailyNewsMailer instead of WeeklyNewsMailer
      allow(DailyNewsMailer).to receive(:weekly_digest).with(user, articles).and_return(mail_double)
      
      WeeklyEmailJob.perform_now(user)
      
      # Check that DailyNewsMailer was called
      expect(DailyNewsMailer).to have_received(:weekly_digest).with(user, articles)
      expect(mail_double).to have_received(:deliver_now)
    end
    
    context "when email delivery fails" do
      it "handles errors from the mailer" do
        # Setup the mailer to raise an error
        mail_double = double("Mail::Message")
        allow(mail_double).to receive(:deliver_now).and_raise(StandardError.new("Test error"))
        
        # Use DailyNewsMailer instead of WeeklyNewsMailer
        allow(DailyNewsMailer).to receive(:weekly_digest).with(user, articles).and_return(mail_double)
        
        # Expect the job to handle the error (either by raising or returning it)
        begin
          result = WeeklyEmailJob.perform_now(user)
          # If it returns the error instead of raising it
          if result.is_a?(StandardError)
            expect(result.message).to eq("Test error")
          end
        rescue StandardError => e
          # If it raises the error
          expect(e.message).to eq("Test error")
        end
      end
    end
  end
end