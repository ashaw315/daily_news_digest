require 'rails_helper'

RSpec.describe EnhancedNewsFetcher, type: :service do
  include_context "rss validation stubs"
  let(:fetcher) { EnhancedNewsFetcher.new }
  
  before(:all) do
    unless defined?(HTTParty)
      class_double("HTTParty").as_stubbed_const
    end
    
    unless defined?(Feedjira)
      class_double("Feedjira").as_stubbed_const
    end

    class AiSummarizerService
      def initialize; end
      def generate_summary(text); "Summary: #{text[0..50]}..."; end
    end
  end

  before do
    # Stub any HTTP requests that might occur
    stub_request(:get, /.*/).to_return(
      status: 200,
      body: rss_feed_xml,
      headers: {'Content-Type' => 'application/rss+xml'}
    )

    # Stub factory if it doesn't exist
    unless defined?(FactoryBot)
      def create(factory_name, attributes = {})
        case factory_name
        when :news_source
          OpenStruct.new({
            id: 1,
            name: attributes[:name] || "Test Source",
            url: attributes[:url] || "http://example.com/feed"
          })
        end
      end
    end
  end
  
  describe "#initialize" do
    it "initializes with empty sources when none provided" do
      expect(fetcher.instance_variable_get(:@sources)).to eq([])
    end
    
    it "accepts custom sources" do
      custom_sources = [create(:news_source, name: 'Custom Source', url: 'http://example.com/feed')]
      custom_fetcher = EnhancedNewsFetcher.new(sources: custom_sources)
      
      expect(custom_fetcher.instance_variable_get(:@sources)).to eq(custom_sources)
    end

    it "initializes an AI summarizer" do
      expect(fetcher.instance_variable_get(:@summarizer)).to be_an_instance_of(AiSummarizerService)
    end
  end
  
  describe "#fetch_articles" do
    let(:news_source) { create(:news_source, name: 'Test Feed', url: 'http://example.com/feed') }
    
    before do
      # Stub external requests
      allow(URI).to receive(:open).and_return(double(read: rss_feed_xml))
      allow(Feedjira).to receive(:parse).and_return(mock_feed)
      
      # Stub the summarizer to return a simple summary
      allow_any_instance_of(AiSummarizerService).to receive(:generate_summary) do |_, text|
        "Summary of: #{text[0..50]}..."
      end
    end
    
    it "fetches articles from RSS feeds" do
      fetcher = EnhancedNewsFetcher.new(sources: [news_source])
      articles = fetcher.fetch_articles
      
      expect(articles).not_to be_empty
      # Since articles are sorted by publish date in reverse order, we should expect Test Article 3
      expect(articles.first[:title]).to eq("Test Article 3")
      expect(articles.first[:source]).to eq("Test Feed")
      expect(articles.first[:news_source_id]).to eq(news_source.id)
    end
    
    it "limits the number of articles per source" do
      fetcher = EnhancedNewsFetcher.new(sources: [news_source])
      articles = fetcher.fetch_articles
      
      expect(articles.length).to eq(EnhancedNewsFetcher::ARTICLES_PER_SOURCE)
    end
    
    it "handles errors from sources gracefully" do
      failing_source = create(:news_source, name: 'Failing Source', url: 'http://failing.com/feed')
      working_source = create(:news_source, name: 'Working Source', url: 'http://working.com/feed')
      
      fetcher = EnhancedNewsFetcher.new(sources: [failing_source, working_source])
      
      # Make the first source fail
      allow(URI).to receive(:open).with(failing_source.url, anything).and_raise(StandardError.new("Test error"))
      allow(URI).to receive(:open).with(working_source.url, anything).and_return(double(read: rss_feed_xml))
      
      articles = fetcher.fetch_articles
      
      expect(articles).not_to be_empty
      expect(articles.first[:source]).to eq("Working Source")
    end
  end
  
  describe "#fetch_full_content_with_readability" do
    let(:url) { "http://example.com/article" }
    let(:html_content) do
      <<~HTML
        <!DOCTYPE html>
        <html>
          <body>
            <article class="article-content">
              <p>This is the full content of the article.</p>
              <p>It has multiple sentences and paragraphs.</p>
              <p>Adding a third paragraph to meet the minimum length requirement.</p>
            </article>
          </body>
        </html>
      HTML
    end
    
    before do
      allow(URI).to receive(:open).and_return(double(read: html_content))
    end
    
    it "extracts article content using Readability" do
      content = fetcher.send(:fetch_full_content_with_readability, url)
      
      expect(content).to include("This is the full content")
      expect(content).to include("multiple sentences")
    end
    
    it "handles HTTP errors gracefully" do
      allow(URI).to receive(:open).and_raise(OpenURI::HTTPError.new("404 Not Found", nil))
      
      content = fetcher.send(:fetch_full_content_with_readability, url)
      expect(content).to eq("")
    end
  end
  
  describe "#save_articles" do
    let(:news_source) { create(:news_source, name: "Test Source") }
    let(:articles) do
      [
        {
          title: "Test Article",
          summary: "Test Summary",
          url: "http://example.com/unique-article",
          publish_date: Time.current,
          source: news_source.name,
          news_source_id: news_source.id,
          topic: "technology"
        }.with_indifferent_access
      ]
    end
    
    it "creates new article records" do
      expect {
        fetcher.send(:save_articles, articles)
      }.to change(Article, :count).by(1)
      
      article = Article.last
      expect(article.title).to eq("Test Article")
      expect(article.summary).to eq("Test Summary")
      expect(article.url).to eq("http://example.com/unique-article")
      expect(article.news_source).to eq(news_source)
      expect(article.topic).to eq("technology")
    end
    
    it "skips existing articles" do
      Article.create!(
        title: "Existing Article",
        url: "http://example.com/unique-article",
        publish_date: 1.day.ago,
        news_source: news_source
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
            <pubDate>#{Time.current.rfc2822}</pubDate>
          </item>
          <item>
            <title>Test Article 2</title>
            <link>http://example.com/article2</link>
            <description>This is another test article about sports</description>
            <pubDate>#{Time.current.rfc2822}</pubDate>
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
        content: nil,
        description: "This is a test article about technology",
        url: "http://example.com/article1",
        link: "http://example.com/article1",
        published: 1.hour.ago,
        categories: ["technology"]
      ),
      double("Entry", 
        title: "Test Article 2", 
        summary: "This is another test article about sports",
        content: nil,
        description: "This is another test article about sports",
        url: "http://example.com/article2",
        link: "http://example.com/article2",
        published: 30.minutes.ago,
        categories: ["sports"]
      ),
      double("Entry", 
        title: "Test Article 3", 
        summary: "This is the most recent article",
        content: nil,
        description: "This is the most recent article",
        url: "http://example.com/article3",
        link: "http://example.com/article3",
        published: Time.current,
        categories: ["technology"]
      )
    ]
    allow(feed).to receive(:entries).and_return(entries)
    feed
  end
end