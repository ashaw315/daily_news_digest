require "rails_helper"

RSpec.describe DailyNewsMailer, type: :mailer do
  describe "daily_digest" do
    let(:user) do
      create(:user,
        email: 'user@example.com',
        name: 'Adam',
        is_subscribed: true
      )
    end
    
    let!(:technology_topic) { create(:topic, name: 'technology') }
    let!(:sports_topic) { create(:topic, name: 'sports') }
    
    before do
      # Clear any existing associations to avoid conflicts
      user.user_topics.destroy_all
      
      # Associate the user with the topics
      UserTopic.create!(user: user, topic: technology_topic)
      UserTopic.create!(user: user, topic: sports_topic)
      
      # Update the JSONB preferences column
      user.update_column(:preferences, { 'topics' => ['technology', 'sports'] })
      
      # Create preferences record if it doesn't exist
      if user.preferences.nil?
        user.create_preferences(email_frequency: 'daily')
      else
        user.preferences.update!(email_frequency: 'daily')
      end
    end
    
    let(:articles) do
      [
        double('Article', 
          title: 'Tech News 1', 
          description: 'Description for tech news 1', 
          source: 'Tech Source', 
          url: 'https://example.com/tech1', 
          published_at: 1.day.ago,
          topic: 'technology'
        ),
        double('Article', 
          title: 'Sports News 1', 
          description: 'Description for sports news 1', 
          source: 'Sports Source', 
          url: 'https://example.com/sports1', 
          published_at: 2.days.ago,
          topic: 'sports'
        )
      ]
    end
    
    let(:mail) { DailyNewsMailer.daily_digest(user, articles) }
    
    it "renders the headers" do
      expect(mail.subject).to include('Daily News Digest')
      expect(mail.to).to eq(['user@example.com'])
      expect(mail.from).to eq(["news@dailynewsdigest.com"])
    end
    
    it "includes a personalized greeting" do
      expect(mail.body.encoded).to include('Hello Adam!')
    end
    
    it "includes the News of the Day Brief section" do
      expect(mail.body.encoded).to include('News of the Day Brief')
    end
    
    it "includes the Trending Topics section" do
      expect(mail.body.encoded).to include('Trending Topics')
      expect(mail.body.encoded).to include('Technology')
      expect(mail.body.encoded).to include('Sports')
    end
    
    it "includes the Top 10 Articles section" do
      expect(mail.body.encoded).to include('Top 10 Articles of the Day')
      expect(mail.body.encoded).to include('Tech News 1')
      expect(mail.body.encoded).to include('Sports News 1')
    end
    
    it "includes articles grouped by topic" do
      expect(mail.body.encoded).to include('Technology News')
      expect(mail.body.encoded).to include('Sports News')
    end
    
    it "includes a footer with unsubscribe and preferences links" do
      expect(mail.body.encoded).to include('Manage Preferences')
      expect(mail.body.encoded).to include('Unsubscribe')
    end
  end

  describe "weekly_digest" do
    let(:user) do
      create(:user,
        email: 'user@example.com',
        name: 'Adam',
        is_subscribed: true
      )
    end
    
    let!(:technology_topic) { create(:topic, name: 'technology') }
    let!(:sports_topic) { create(:topic, name: 'sports') }
    
    before do
      # Clear any existing associations to avoid conflicts
      user.user_topics.destroy_all
      
      # Associate the user with the topics
      UserTopic.create!(user: user, topic: technology_topic)
      UserTopic.create!(user: user, topic: sports_topic)
      
      # Update the JSONB preferences column
      user.update_column(:preferences, { 'topics' => ['technology', 'sports'] })
      
      # Create preferences record if it doesn't exist
      if user.preferences.nil?
        user.create_preferences(email_frequency: 'weekly')
      else
        user.preferences.update!(email_frequency: 'weekly')
      end
    end
    
    let(:articles) do
      [
        double('Article', 
          title: 'Tech News 1', 
          description: 'Description for tech news 1', 
          source: 'Tech Source', 
          url: 'https://example.com/tech1', 
          published_at: 1.day.ago,
          topic: 'technology'
        ),
        double('Article', 
          title: 'Sports News 1', 
          description: 'Description for sports news 1', 
          source: 'Sports Source', 
          url: 'https://example.com/sports1', 
          published_at: 2.days.ago,
          topic: 'sports'
        )
      ]
    end
    
    let(:mail) { DailyNewsMailer.weekly_digest(user, articles) }
    
    it "renders the headers" do
      expect(mail.subject).to include('Weekly News Digest')
      expect(mail.to).to eq(['user@example.com'])
      expect(mail.from).to eq(["news@dailynewsdigest.com"])
    end
    
    # Similar tests as for daily_digest
    it "includes a personalized greeting" do
      expect(mail.body.encoded).to include('Hello Adam!')
    end
    
    it "includes the Weekly News Brief section" do
      expect(mail.body.encoded).to include('Weekly News Brief')
    end
    
    it "includes a footer with unsubscribe and preferences links" do
      expect(mail.body.encoded).to include('Manage Preferences')
      expect(mail.body.encoded).to include('Unsubscribe')
    end
  end
end