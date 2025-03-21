require 'rails_helper'

RSpec.describe Article, type: :model do
  describe 'validations' do
    subject { create(:article) }

    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:url) }
    it { should validate_uniqueness_of(:url) }
    it { should validate_presence_of(:publish_date) }
  end

  describe 'scopes' do
    let!(:tech_article) { create(:article, topic: 'tech') }
    let!(:science_article) { create(:article, topic: 'science') }

    it 'filters by topic' do
      expect(Article.by_topic('tech')).to include(tech_article)
      expect(Article.by_topic('tech')).not_to include(science_article)
    end

    it 'orders by recent publish date' do
      expect(Article.recent).to eq(Article.order(publish_date: :desc))
    end
  end
end