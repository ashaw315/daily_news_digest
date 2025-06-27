require "rails_helper"

RSpec.describe DailyNewsMailer, type: :mailer do
  describe "daily_digest" do
    # Fix topic names - remove "News" since it's being appended
    let(:tech_topic) { create(:topic, name: 'Technology') }
    let(:sports_topic) { create(:topic, name: 'Sports') }
    
    let(:tech_source) { create(:news_source, name: 'Tech Source', topic: tech_topic) }
    let(:sports_source) { create(:news_source, name: 'Sports Source', topic: sports_topic) }

    let(:user) do
      user = create(:user,
        email: 'user@example.com',
        name: 'Adam',
        is_subscribed: true
      )
      user.news_source_ids = [tech_source.id, sports_source.id]
      user.save!
      user
    end

    let(:articles) do
      [
        create(:article,
          title: 'Tech News 1',
          summary: 'Summary for tech news 1',
          url: 'https://example.com/tech1',
          publish_date: 1.day.ago,
          news_source: tech_source
        ),
        create(:article,
          title: 'Sports News 1',
          summary: 'Summary for sports news 1',
          url: 'https://example.com/sports1',
          publish_date: 2.days.ago,
          news_source: sports_source
        )
      ]
    end

    let(:mail) { DailyNewsMailer.daily_digest(user, articles) }

    it "renders the headers" do
      expect(mail.subject).to eq("Your Daily News Digest - #{Date.today.strftime('%B %d, %Y')}")
      expect(mail.to).to eq(['user@example.com'])
      expect(mail.from).to eq(["news@dailynewsdigest.com"])
    end

    it "includes articles grouped by topic" do
      body = mail.body.encoded
      
      # Update expectations to match actual template output
      expect(body).to include('Technology News')  # Template adds "News"
      expect(body).to include('Sports News')      # Template adds "News"
      
      # Check article titles and summaries
      expect(body).to include('Tech News 1')
      expect(body).to include('Sports News 1')
      expect(body).to include('Summary for tech news 1')
      expect(body).to include('Summary for sports news 1')
    end

    it "includes source names" do
      body = mail.body.encoded
      expect(body).to include('Tech Source')
      expect(body).to include('Sports Source')
    end
  end
end