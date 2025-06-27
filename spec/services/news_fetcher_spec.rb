# require 'rails_helper'

# RSpec.describe NewsFetcher, type: :service do
#   include_context "rss validation stubs"
#   let(:fetcher) { NewsFetcher.new }
  
#   before(:all) do
#     unless defined?(HTTParty)
#       class_double("HTTParty").as_stubbed_const
#     end
    
#     unless defined?(Feedjira)
#       class_double("Feedjira").as_stubbed_const
#     end
#   end

#   # Add this at the top level of the describe block
#   before do
#     # Stub any HTTP requests that might occur
#     stub_request(:get, /.*/).to_return(
#       status: 200,
#       body: rss_feed_xml,
#       headers: {'Content-Type' => 'application/rss+xml'}
#     )
#   end
  
#   describe "#initialize" do
#     it "initializes with empty sources when none provided" do
#       expect(fetcher.sources).to eq([])
#     end
    
#     it "uses default topics when none provided" do
#       expect(fetcher.topics).not_to be_empty
#       expect(fetcher.topics).to include('politics', 'technology')
#     end
    
#     it "accepts custom sources and topics" do
#       custom_sources = [{ name: 'Custom Source', url: 'http://example.com/feed' }]
#       custom_topics = ['custom_topic_1', 'custom_topic_2']
      
#       custom_fetcher = NewsFetcher.new(sources: custom_sources, topics: custom_topics)
      
#       expect(custom_fetcher.sources).to eq(custom_sources)
#       expect(custom_fetcher.topics).to eq(custom_topics)
#     end
#   end
  
#   describe "#fetch_articles" do
#     before do
#       # Stub external requests
#       allow(HTTParty).to receive(:get).and_return(double(body: rss_feed_xml, code: 200))
#       allow(Feedjira).to receive(:parse).and_return(mock_feed)
      
#       # Stub categorization to avoid training the classifier in tests
#       allow_any_instance_of(NewsFetcher).to receive(:categorize_articles) do |_, articles|
#         articles.each { |article| article[:topic] = 'technology' }
#       end
#     end
    
#     it "fetches articles from RSS feeds" do
#       # Create a fetcher with explicit sources
#       rss_sources = [{ name: 'BBC News', url: 'http://feeds.bbci.co.uk/news/rss.xml' }]
#       rss_fetcher = NewsFetcher.new(sources: rss_sources)
      
#       articles = rss_fetcher.fetch_articles
      
#       expect(articles).not_to be_empty
#       expect(articles.first[:title]).to eq("Test Article 1")
#       expect(articles.first[:source]).to eq("BBC News")
#     end
    
#     it "limits the number of articles per source" do
#       # Create sources
#       rss_sources = [{ name: 'BBC News', url: 'http://feeds.bbci.co.uk/news/rss.xml' }]
      
#       # Create a new fetcher with max_articles: 1
#       limited_fetcher = NewsFetcher.new(sources: rss_sources, max_articles: 1)
      
#       # Stub fetch_from_rss to return a single article
#       allow(limited_fetcher).to receive(:fetch_from_rss).and_return([
#         {
#           title: "Test Article 1", 
#           description: "This is a test article about technology",
#           url: "http://example.com/article1",
#           published_at: Time.now
#         }.with_indifferent_access
#       ])
      
#       # Stub categorize_articles to do nothing
#       allow(limited_fetcher).to receive(:categorize_articles)
      
#       articles = limited_fetcher.fetch_articles
      
#       expect(articles.length).to eq(1)
#     end
    
#     it "handles errors from sources gracefully" do
#       # Create a fetcher with our own sources
#       sources = [
#         { name: 'Failing Source', url: 'http://failing.com/feed' },
#         { name: 'Working Source', url: 'http://working.com/feed' }
#       ]
#       multi_source_fetcher = NewsFetcher.new(sources: sources)
      
#       # Stub fetch_from_rss to fail for the first source and succeed for the second
#       allow(multi_source_fetcher).to receive(:fetch_from_rss) do |source|
#         if source[:name] == 'Failing Source'
#           raise StandardError.new("Test error")
#         else
#           [{
#             title: "Working Article",
#             description: "This article is from the working source",
#             url: "http://working.com/article",
#             published_at: Time.now
#           }.with_indifferent_access]
#         end
#       end
      
#       # Stub categorize_articles
#       allow(multi_source_fetcher).to receive(:categorize_articles)
      
#       articles = multi_source_fetcher.fetch_articles
      
#       expect(articles).not_to be_empty
#       expect(articles.first[:title]).to eq("Working Article")
#       expect(multi_source_fetcher.errors).not_to be_empty
#     end
#   end
  
#   describe "#fetch_from_rss" do
#     before do
#       allow(HTTParty).to receive(:get).and_return(double(body: rss_feed_xml))
#       allow(Feedjira).to receive(:parse).and_return(mock_feed)
#     end
    
#     it "parses RSS feeds correctly" do
#       source = { name: 'Test Feed', url: 'http://example.com/feed' }
#       articles = fetcher.send(:fetch_from_rss, source)
      
#       expect(articles.length).to eq(2)
#       expect(articles.first[:title]).to eq("Test Article 1")
#       expect(articles.first[:description]).to eq("This is a test article about technology")
#       expect(articles.first[:url]).to eq("http://example.com/article1")
#     end
    
#     it "respects the limit parameter" do
#       source = { name: 'Test Feed', url: 'http://example.com/feed' }
#       articles = fetcher.send(:fetch_from_rss, source, 1)
      
#       expect(articles.length).to eq(1)
#     end
#   end
  
#   describe "#categorize_articles" do
#     let(:articles) do
#       [
#         {
#           title: "New AI breakthrough",
#           description: "Researchers develop advanced machine learning algorithm",
#           url: "http://example.com/ai-news",
#           published_at: Time.now
#         }.with_indifferent_access,
#         {
#           title: "Election results",
#           description: "Latest updates on the presidential election",
#           url: "http://example.com/politics",
#           published_at: Time.now
#         }.with_indifferent_access
#       ]
#     end
  
#     before do
#       # Mock OpenAI API calls
#       allow_any_instance_of(OpenAI::Client).to receive(:chat).and_return(
#         OpenStruct.new(
#           "choices" => [
#             {
#               "message" => {
#                 "content" => "technology"
#               }
#             }
#           ]
#         )
#       )
#     end
  
#     it "assigns topics to articles using OpenAI" do
#       fetcher.send(:categorize_articles, articles)
      
#       expect(articles[0][:topic]).to eq('technology')
#       # The second article will also get 'technology' in this test because we mocked
#       # the OpenAI response to always return 'technology'
#     end
  
#     it "handles OpenAI API errors gracefully" do
#       allow_any_instance_of(OpenAI::Client).to receive(:chat).and_raise(StandardError.new("API Error"))
      
#       # Should not raise an error
#       expect { 
#         fetcher.send(:categorize_articles, articles)
#       }.not_to raise_error
      
#       # Topics should be nil due to the error
#       expect(articles[0][:topic]).to be_nil
#       expect(articles[1][:topic]).to be_nil
#     end
#   end
  
#   describe "#extract_keywords" do
#     it "extracts relevant keywords from text" do
#       text = "The quick brown fox jumps over the lazy dog. Fox is quick and brown."
#       keywords = fetcher.send(:extract_keywords, text, 3)
      
#       expect(keywords.keys).to include("fox")
#       expect(keywords.keys).to include("quick")
#       expect(keywords.keys).to include("brown")
#       expect(keywords.keys).not_to include("the")
#     end
    
#     it "removes stopwords" do
#       text = "The quick brown fox jumps over the lazy dog."
#       keywords = fetcher.send(:extract_keywords, text)
      
#       expect(keywords.keys).not_to include("the")
#       expect(keywords.keys).not_to include("over")
#     end
#   end
  
#   describe "#save_articles" do
#     let(:news_source) { create(:news_source, name: "Test Source") }
#     let(:articles) do
#       [
#         {
#           title: "Test Article",
#           description: "Test Description",
#           url: "http://example.com/unique-article",
#           published_at: Time.now,
#           source: news_source.name,  # Use the news source name
#           topic: "technology",
#           news_source_id: news_source.id  # Add the news source ID
#         }.with_indifferent_access
#       ]
#     end
    
#     it "creates new article records" do
#       expect {
#         fetcher.send(:save_articles, articles)
#       }.to change(Article, :count).by(1)
      
#       article = Article.last
#       expect(article.title).to eq("Test Article")
#       expect(article.summary).to eq("Test Description")
#       expect(article.url).to eq("http://example.com/unique-article")
#       expect(article.news_source).to eq(news_source)
#       expect(article.topic).to eq("technology")
#     end
    
#     it "skips existing articles" do
#       # Create an article with the same URL
#       Article.create!(
#         title: "Existing Article",
#         url: "http://example.com/unique-article",
#         publish_date: 1.day.ago,
#         news_source: news_source  # Use the same news source
#       )
      
#       expect {
#         fetcher.send(:save_articles, articles)
#       }.not_to change(Article, :count)
#     end
#   end
  
#   describe "#enhance_articles_with_detailed_summaries" do
#     let(:articles) do
#       [
#         {
#           title: "Test Article",
#           description: "Original description",
#           url: "http://example.com/article",
#           published_at: Time.now
#         }.with_indifferent_access
#       ]
#     end
    
#     let(:html_content) do
#       <<~HTML
#         <!DOCTYPE html>
#         <html>
#           <body>
#             <article class="article-content">
#               <p>This is the full content of the article.</p>
#               <p>It has multiple sentences and paragraphs.</p>
#               <p>Adding a third paragraph to meet the minimum length requirement.</p>
#               <p>And a fourth paragraph to ensure we have enough content.</p>
#             </article>
#           </body>
#         </html>
#       HTML
#     end
  
#     before do
#       # Mock Rails logger
#       allow(Rails.logger).to receive(:info)
#       allow(Rails.logger).to receive(:warn)
#       allow(Rails.logger).to receive(:error)
  
#       # Mock Rails cache
#       allow(Rails.cache).to receive(:read).and_return(nil)
#       allow(Rails.cache).to receive(:write).and_return(nil)
  
#       # Create a mock response object
#       mock_response = double('Response')
#       allow(mock_response).to receive(:read).and_return(html_content)
  
#       # Stub URI.open
#       allow(URI).to receive(:open).with(
#         anything,
#         hash_including(
#           'User-Agent' => anything,
#           'Accept' => anything,
#           'Accept-Language' => anything
#         )
#       ).and_return(mock_response)
  
#       # Stub HTTParty for RSS feed
#       stub_request(:get, "http://example.com/article").
#         to_return(status: 200, body: html_content, headers: {'Content-Type' => 'text/html'})
#     end
    
#     it "enhances articles with full content" do
#       # Create fetcher with detailed preview enabled
#       preview_fetcher = NewsFetcher.new(detailed_preview: true)
      
#       # Disable AI summarizer
#       preview_fetcher.instance_variable_set(:@summarizer, nil)
      
#       # Call the method
#       enhanced_articles = preview_fetcher.send(:enhance_articles_with_detailed_summaries, articles)
      
#       # Debug output
#       puts "Enhanced article content: #{enhanced_articles.first[:content].inspect}"
#       puts "Enhanced article description: #{enhanced_articles.first[:description].inspect}"
      
#       # Add expectations
#       aggregate_failures do
#         expect(enhanced_articles.first[:content]).not_to be_nil
#         expect(enhanced_articles.first[:content].to_s).to include("This is the full content")
#         expect(enhanced_articles.first[:description].to_s).to include("This is the full content")
#       end
#     end
  
#     it "skips articles without a URL" do
#       article_without_url = { 
#         title: "No URL Article", 
#         description: "Description" 
#       }.with_indifferent_access
      
#       preview_fetcher = NewsFetcher.new(detailed_preview: true)
#       enhanced_articles = preview_fetcher.send(:enhance_articles_with_detailed_summaries, [article_without_url])
      
#       expect(enhanced_articles.first[:title]).to eq("No URL Article")
#       expect(enhanced_articles.first[:content]).to be_nil
#     end
#   end
  
#   # Helper methods for tests
#   def rss_feed_xml
#     <<~XML
#       <?xml version="1.0" encoding="UTF-8"?>
#       <rss version="2.0">
#         <channel>
#           <title>Test Feed</title>
#           <link>http://example.com</link>
#           <description>Test RSS Feed</description>
#           <item>
#             <title>Test Article 1</title>
#             <link>http://example.com/article1</link>
#             <description>This is a test article about technology</description>
#             <pubDate>#{Time.now.rfc2822}</pubDate>
#           </item>
#           <item>
#             <title>Test Article 2</title>
#             <link>http://example.com/article2</link>
#             <description>This is another test article about sports</description>
#             <pubDate>#{Time.now.rfc2822}</pubDate>
#           </item>
#         </channel>
#       </rss>
#     XML
#   end
  
#   def mock_feed
#     feed = double("Feed")
#     entries = [
#       double("Entry", 
#         title: "Test Article 1", 
#         summary: "This is a test article about technology",
#         url: "http://example.com/article1",
#         link: "http://example.com/article1",
#         published: Time.now,
#         content: nil
#       ),
#       double("Entry", 
#         title: "Test Article 2", 
#         summary: "This is another test article about sports",
#         url: "http://example.com/article2",
#         link: "http://example.com/article2",
#         published: Time.now,
#         content: nil
#       )
#     ]
#     allow(feed).to receive(:entries).and_return(entries)
#     feed
#   end
# end