require 'rails_helper'

RSpec.describe Article, type: :model do
  let(:news_source) { create(:news_source) }

  describe 'associations' do
    it { should belong_to(:news_source) }
  end

  describe 'validations' do
    let!(:existing_article) { create(:article, news_source: news_source) }
    
    subject { build(:article, news_source: news_source) }
  
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:url) }
    it { should validate_presence_of(:publish_date) }
    it { should validate_presence_of(:news_source) }
    
    it 'validates uniqueness of url' do
      duplicate_article = build(:article, url: existing_article.url, news_source: news_source)
      expect(duplicate_article).not_to be_valid
      expect(duplicate_article.errors[:url]).to include('has already been taken')
    end
  end

  describe 'scopes' do
    let(:news_source) { create(:news_source, name: 'CNN') }
    let(:second_source) { create(:news_source, name: 'BBC') }
    let!(:tech_article) { create(:article, topic: 'tech', news_source: news_source) }
    let!(:science_article) { create(:article, topic: 'science', news_source: second_source) }

    it 'filters by topic' do
      expect(Article.by_topic('tech')).to include(tech_article)
      expect(Article.by_topic('tech')).not_to include(science_article)
    end

    it 'filters by news_source' do
      expect(Article.by_source(news_source)).to include(tech_article)
      expect(Article.by_source(news_source)).not_to include(science_article)
    end

    it 'orders by recent publish date' do
      expect(Article.recent).to eq(Article.order(publish_date: :desc))
    end
  end

  describe '#related_articles' do
    let(:news_source) { create(:news_source) }
    let!(:tech_article1) { create(:article, topic: 'tech', news_source: news_source) }
    let!(:tech_article2) { create(:article, topic: 'tech', news_source: news_source) }
    let!(:science_article) { create(:article, topic: 'science', news_source: news_source) }

    it 'returns articles with the same topic' do
      related = tech_article1.related_articles
      expect(related).to include(tech_article2)
      expect(related).not_to include(tech_article1) # Should not include self
      expect(related).not_to include(science_article)
    end

    it 'limits the number of results' do
      # Create additional tech articles
      5.times { create(:article, topic: 'tech', news_source: news_source) }
      
      # Should return at most 5 related articles by default
      expect(tech_article1.related_articles.size).to eq(5)
      
      # Should respect the limit parameter
      expect(tech_article1.related_articles(2).size).to eq(2)
    end
  end

  describe '#keywords' do
    let(:news_source) { create(:news_source) }
    let(:article) { 
      create(:article, 
        title: 'Advanced Ruby Programming Techniques', 
        summary: 'Learn about metaprogramming, DSLs, and functional programming in Ruby',
        news_source: news_source
      ) 
    }
  
    it 'extracts keywords from title and summary' do
      keywords = article.keywords
      
      # Check that it returns an array of strings
      expect(keywords).to be_an(Array)
      expect(keywords).to all(be_a(String))
      
      # Check that it contains expected keywords from the title and summary
      expect(keywords).to include('ruby')
      expect(keywords).to include('programming')
      
      # Check that common stopwords are excluded
      expect(keywords).not_to include('about', 'and', 'in')
    end
  
    it 'respects the count parameter' do
      expect(article.keywords(3).size).to eq(3)
    end
  end

  describe 'helper methods' do
    let(:news_source) { create(:news_source, name: 'CNN', url: 'https://cnn.com/rss') }
    let(:article) { create(:article, news_source: news_source) }

    describe '#source_name' do
      it 'returns the name of the associated news source' do
        expect(article.source_name).to eq('CNN')
      end

      it 'returns nil if news_source is nil' do
        article.news_source = nil
        expect(article.source_name).to be_nil
      end
    end

    describe '#source_url' do
      it 'returns the url of the associated news source' do
        expect(article.source_url).to eq('https://cnn.com/rss')
      end

      it 'returns nil if news_source is nil' do
        article.news_source = nil
        expect(article.source_url).to be_nil
      end
    end
  end
end