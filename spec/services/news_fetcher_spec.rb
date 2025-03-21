require 'rails_helper'

RSpec.describe NewsFetcher, type: :service do
  let(:fetcher) { NewsFetcher.new }
  
  before(:all) do
    # Check if HTTParty is available, if not, stub it
    unless defined?(HTTParty)
      class_double("HTTParty").as_stubbed_const
    end
    
    # Check if Feedjira is available, if not, stub it
    unless defined?(Feedjira)
      class_double("Feedjira").as_stubbed_const
    end
    
    # Check if Robotstxt is available, if not, stub it
    unless defined?(Robotstxt)
      module Robotstxt
        class Parser
          def initialize(robots_txt)
          end
          
          def allowed?(user_agent, path)
            true # Default to allowing in tests
          end
        end
      end
    end
  end
  
  describe "#initialize" do
    it "uses default sources when none provided" do
      expect(fetcher.sources).not_to be_empty
      expect(fetcher.sources.first).to include(:name, :type, :url)
    end
    
    it "uses default topics when none provided" do
      expect(fetcher.topics).not_to be_empty
      expect(fetcher.topics).to include('politics', 'technology')
    end
    
    it "accepts custom sources and topics" do
      custom_sources = [{ name: 'Custom Source', type: :rss, url: 'http://example.com/feed' }]
      custom_topics = ['custom_topic_1', 'custom_topic_2']
      
      custom_fetcher = NewsFetcher.new(sources: custom_sources, topics: custom_topics)
      
      expect(custom_fetcher.sources).to eq(custom_sources)
      expect(custom_fetcher.topics).to eq(custom_topics)
    end
  end
  
  describe "#fetch_articles" do
    before do
      # Stub external requests
      allow(HTTParty).to receive(:get).and_return(double(body: rss_feed_xml, code: 200))
      allow(Feedjira).to receive(:parse).and_return(mock_feed)
      
      # Stub the robots.txt check
      allow_any_instance_of(NewsFetcher).to receive(:scraping_allowed?).and_return(true)
      
      # Stub categorization to avoid training the classifier in tests
      allow_any_instance_of(NewsFetcher).to receive(:categorize_articles) do |_, articles|
        articles.each { |article| article.topic = 'technology' }
      end
      
      # Stub the default sources to include only RSS for simplicity
      allow_any_instance_of(NewsFetcher).to receive(:default_sources).and_return([
        { name: 'BBC News', type: :rss, url: 'http://feeds.bbci.co.uk/news/rss.xml' }
      ])
    end
    
    it "fetches articles from RSS feeds" do
      articles = fetcher.fetch_articles
      
      expect(articles).not_to be_empty
      expect(articles.first.title).to eq("Test Article 1")
      expect(articles.first.source).to eq("BBC News")
    end
    
    it "limits the number of articles per source" do
      # Set a low max_articles limit
      limited_fetcher = NewsFetcher.new(max_articles: 1)
      allow(limited_fetcher).to receive(:categorize_articles)
      
      articles = limited_fetcher.fetch_articles
      
      expect(articles.length).to eq(1)
    end
    
    it "handles errors from sources gracefully" do
      # Make the first source fail
      allow(HTTParty).to receive(:get).and_raise(StandardError.new("Test error"))
      
      # But allow the second source to work
      allow(fetcher).to receive(:fetch_from_api).and_return([
        OpenStruct.new(
          title: "API Article",
          description: "API Description",
          url: "http://api.com/article",
          published_at: Time.now
        )
      ])
      
      # Should continue to the next source
      articles = fetcher.fetch_articles
      
      expect(articles).not_to be_empty
      expect(articles.first.title).to eq("API Article")
    end
    
    it "saves articles to the database" do
      expect {
        fetcher.fetch_articles
      }.to change(Article, :count).by(2)
    end
    
    it "doesn't save duplicate articles" do
      # Create an article with the same URL
      Article.create!(
        title: "Test Article 1",
        url: "http://example.com/article1",
        publish_date: Time.now
      )
      
      expect {
        fetcher.fetch_articles
      }.to change(Article, :count).by(1) # Only saves the second article
    end
  end
  
  describe "#fetch_from_rss" do
    before do
      allow(HTTParty).to receive(:get).and_return(double(body: rss_feed_xml))
      allow(Feedjira).to receive(:parse).and_return(mock_feed)
    end
    
    it "parses RSS feeds correctly" do
      source = { name: 'Test Feed', type: :rss, url: 'http://example.com/feed' }
      articles = fetcher.send(:fetch_from_rss, source)
      
      expect(articles.length).to eq(2)
      expect(articles.first.title).to eq("Test Article 1")
      expect(articles.first.description).to eq("This is a test article about technology")
      expect(articles.first.url).to eq("http://example.com/article1")
    end
  end
  
  describe "#categorize_articles" do
    let(:articles) do
      [
        OpenStruct.new(
          title: "New AI breakthrough",
          description: "Researchers develop advanced machine learning algorithm",
          url: "http://example.com/ai-news",
          published_at: Time.now
        ),
        OpenStruct.new(
          title: "Election results",
          description: "Latest updates on the presidential election",
          url: "http://example.com/politics",
          published_at: Time.now
        )
      ]
    end
    
    it "assigns topics to articles" do
      # Use the real categorization
      fetcher.send(:categorize_articles, articles)
      
      expect(articles[0].topic).not_to be_nil
      expect(articles[1].topic).not_to be_nil
      
      # The first article should be categorized as technology
      expect(articles[0].topic).to eq('technology')
      
      # The second article should be categorized as politics
      expect(articles[1].topic).to eq('politics')
    end
  end
  
  describe "#extract_keywords" do
    it "extracts relevant keywords from text" do
      text = "The quick brown fox jumps over the lazy dog. Fox is quick and brown."
      keywords = fetcher.send(:extract_keywords, text, 3)
      
      expect(keywords).to include("fox")
      expect(keywords).to include("quick")
      expect(keywords).to include("brown")
    end
    
    it "removes stopwords" do
      text = "The quick brown fox jumps over the lazy dog."
      keywords = fetcher.send(:extract_keywords, text)
      
      expect(keywords).not_to include("the")
      expect(keywords).not_to include("over")
    end
  end
  
  describe "#save_articles" do
    let(:articles) do
      [
        OpenStruct.new(
          title: "Test Article",
          description: "Test Description",
          url: "http://example.com/unique-article",
          published_at: Time.now,
          source: "Test Source",
          topic: "technology"
        )
      ]
    end
    
    it "creates new article records" do
      expect {
        fetcher.send(:save_articles, articles)
      }.to change(Article, :count).by(1)
      
      article = Article.last
      expect(article.title).to eq("Test Article")
      expect(article.summary).to eq("Test Description")
      expect(article.url).to eq("http://example.com/unique-article")
      expect(article.source).to eq("Test Source")
      expect(article.topic).to eq("technology")
    end
    
    it "skips existing articles" do
      # Create an article with the same URL
      Article.create!(
        title: "Existing Article",
        url: "http://example.com/unique-article",
        publish_date: 1.day.ago
      )
      
      expect {
        fetcher.send(:save_articles, articles)
      }.not_to change(Article, :count)
    end
  end
  
  # Helper methods for tests
  def rss_feed_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Test Feed</title>
          <link>http://example.com</link>
          <description>Test RSS Feed</description>
          <item>
            <title>Test Article 1</title>
            <link>http://example.com/article1</link>
            <description>This is a test article about technology</description>
            <pubDate>#{Time.now.rfc2822}</pubDate>
          </item>
          <item>
            <title>Test Article 2</title>
            <link>http://example.com/article2</link>
            <description>This is another test article about sports</description>
            <pubDate>#{Time.now.rfc2822}</pubDate>
          </item>
        </channel>
      </rss>
    XML
  end
  
  def mock_feed
    feed = double("Feed")
    entries = [
      double("Entry", 
        title: "Test Article 1", 
        summary: "This is a test article about technology",
        url: "http://example.com/article1",
        link: "http://example.com/article1",
        published: Time.now,
        content: nil
      ),
      double("Entry", 
        title: "Test Article 2", 
        summary: "This is another test article about sports",
        url: "http://example.com/article2",
        link: "http://example.com/article2",
        published: Time.now,
        content: nil
      )
    ]
    allow(feed).to receive(:entries).and_return(entries)
    feed
  end
end 