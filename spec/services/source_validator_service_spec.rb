require 'rails_helper'
require 'webmock/rspec'

RSpec.describe SourceValidatorService do
  let(:rss_source) { build(:news_source, format: 'rss', url: 'https://example.com/rss.xml', settings: {}) }
  let(:api_source) { build(:news_source, format: 'api', url: 'https://api.example.com/news', settings: { 'api_key' => 'test_key', 'api_key_param' => 'key', 'response_path' => 'articles' }) }
  let(:invalid_source) { build(:news_source, format: 'invalid', url: 'https://example.com', settings: {}) }

  describe '#validate' do
    context 'with an unsupported format' do
      it 'returns false and adds an error' do
        service = described_class.new(invalid_source)
        expect(service.validate).to be false
        expect(service.errors).to include("Unsupported format: invalid")
      end
    end

    context 'with an RSS source' do
      let(:valid_rss_xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <rss version="2.0">
            <channel>
              <title>Test RSS Feed</title>
              <link>https://example.com</link>
              <description>A test RSS feed</description>
              <item>
                <title>Test Article</title>
                <link>https://example.com/article1</link>
                <description>This is a test article</description>
                <pubDate>Mon, 01 Jan 2023 12:00:00 GMT</pubDate>
              </item>
              <item>
                <title>Another Test Article</title>
                <link>https://example.com/article2</link>
                <description>This is another test article</description>
                <pubDate>Tue, 02 Jan 2023 12:00:00 GMT</pubDate>
              </item>
            </channel>
          </rss>
        XML
      end

      let(:empty_rss_xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <rss version="2.0">
            <channel>
              <title>Empty RSS Feed</title>
              <link>https://example.com</link>
              <description>An empty RSS feed</description>
            </channel>
          </rss>
        XML
      end

      let(:invalid_rss_xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <invalid>
            This is not a valid RSS feed
          </invalid>
        XML
      end

      it 'returns true for a valid RSS feed' do
        stub_request(:get, rss_source.url)
          .to_return(status: 200, body: valid_rss_xml, headers: { 'Content-Type' => 'application/xml' })

        service = described_class.new(rss_source)
        expect(service.validate).to be true
        expect(service.errors).to be_empty
      end

      it 'returns false for an empty RSS feed' do
        stub_request(:get, rss_source.url)
          .to_return(status: 200, body: empty_rss_xml, headers: { 'Content-Type' => 'application/xml' })

        service = described_class.new(rss_source)
        expect(service.validate).to be false
        expect(service.errors).to include("RSS feed contains no items")
      end

      it 'returns false for an invalid RSS feed' do
        stub_request(:get, rss_source.url)
          .to_return(status: 200, body: invalid_rss_xml, headers: { 'Content-Type' => 'application/xml' })

        service = described_class.new(rss_source)
        expect(service.validate).to be false
        expect(service.errors).to include("Not a valid RSS feed")
      end

      it 'returns false for a failed HTTP request' do
        stub_request(:get, rss_source.url)
          .to_return(status: 404, body: "Not Found", headers: {})

        service = described_class.new(rss_source)
        expect(service.validate).to be false
        expect(service.errors).to include("HTTP request failed with status code: 404")
      end

      it 'returns false for an invalid URL' do
        invalid_url_source = build(:news_source, format: 'rss', url: 'not a url', settings: {})
        service = described_class.new(invalid_url_source)
        expect(service.validate).to be false
        expect(service.errors).to include("Invalid URL format")
      end
    end

    context 'with an API source' do
      let(:valid_api_response) do
        {
          articles: [
            {
              title: "Test Article",
              url: "https://example.com/article1",
              description: "This is a test article"
            },
            {
              title: "Another Test Article",
              url: "https://example.com/article2",
              description: "This is another test article"
            }
          ]
        }.to_json
      end

      let(:empty_api_response) do
        {
          articles: []
        }.to_json
      end

      let(:invalid_api_response) do
        "This is not valid JSON"
      end

      let(:unexpected_structure_response) do
        {
          something_else: {
            not_articles: []
          }
        }.to_json
      end

      it 'returns true for a valid API response' do
        stub_request(:get, "https://api.example.com/news?key=test_key")
          .to_return(status: 200, body: valid_api_response, headers: { 'Content-Type' => 'application/json' })

        service = described_class.new(api_source)
        expect(service.validate).to be true
        expect(service.errors).to be_empty
      end

      it 'returns false for an empty API response' do
        stub_request(:get, "https://api.example.com/news?key=test_key")
          .to_return(status: 200, body: empty_api_response, headers: { 'Content-Type' => 'application/json' })

        service = described_class.new(api_source)
        expect(service.validate).to be false
        expect(service.errors).to include("API response doesn't have the expected structure")
      end

      it 'returns false for invalid JSON' do
        stub_request(:get, "https://api.example.com/news?key=test_key")
          .to_return(status: 200, body: invalid_api_response, headers: { 'Content-Type' => 'application/json' })

        service = described_class.new(api_source)
        expect(service.validate).to be false
        expect(service.errors).to include("API response is not valid JSON")
      end

      it 'returns false for unexpected structure' do
        stub_request(:get, "https://api.example.com/news?key=test_key")
          .to_return(status: 200, body: unexpected_structure_response, headers: { 'Content-Type' => 'application/json' })

        service = described_class.new(api_source)
        expect(service.validate).to be false
        expect(service.errors).to include("API response doesn't have the expected structure")
      end

      it 'returns false for a failed HTTP request' do
        stub_request(:get, "https://api.example.com/news?key=test_key")
          .to_return(status: 403, body: "Forbidden", headers: {})

        service = described_class.new(api_source)
        expect(service.validate).to be false
        expect(service.errors).to include("API request failed with status code: 403")
      end

      it 'returns false for an invalid URL' do
        invalid_url_source = build(:news_source, format: 'api', url: 'not a url', settings: { 'api_key' => 'test_key' })
        service = described_class.new(invalid_url_source)
        expect(service.validate).to be false
        expect(service.errors).to include("Invalid URL format")
      end
    end
  end

  describe '#has_required_rss_fields?' do
    let(:service) { described_class.new(rss_source) }
    
    it 'returns true when all required fields are present' do
      item = double(
        title: 'Test Title',
        link: 'https://example.com/article',
        description: 'Test description',
        respond_to?: true
      )
      allow(item).to receive(:present?).and_return(true)
      
      expect(service.send(:has_required_rss_fields?, item)).to be true
    end
    
    it 'returns false when title is missing' do
      item = double(
        title: nil,
        link: 'https://example.com/article',
        description: 'Test description',
        respond_to?: true
      )
      allow(item).to receive(:present?).and_return(false)
      
      expect(service.send(:has_required_rss_fields?, item)).to be false
    end
    
    it 'returns false when link is missing' do
      item = double(
        title: 'Test Title',
        link: nil,
        description: 'Test description',
        respond_to?: true
      )
      allow(item).to receive(:present?).and_return(false)
      
      expect(service.send(:has_required_rss_fields?, item)).to be false
    end
    
    it 'returns false when both description and content are missing' do
      item = double(
        title: 'Test Title',
        link: 'https://example.com/article',
        description: nil,
        content: nil,
        respond_to?: true
      )
      allow(item).to receive(:present?).and_return(false)
      
      expect(service.send(:has_required_rss_fields?, item)).to be false
    end
  end

  describe '#has_valid_api_structure?' do
    let(:service) { described_class.new(api_source) }
    
    it 'returns true when response_path points to an array of items' do
      json = { 'articles' => [{ 'title' => 'Test' }] }
      expect(service.send(:has_valid_api_structure?, json)).to be true
    end
    
    it 'returns false when response_path points to a non-existent field' do
      json = { 'data' => [{ 'title' => 'Test' }] }
      expect(service.send(:has_valid_api_structure?, json)).to be false
    end
    
    it 'returns false when response_path points to an empty array' do
      json = { 'articles' => [] }
      expect(service.send(:has_valid_api_structure?, json)).to be false
    end
    
    it 'returns false when response_path points to a non-array' do
      json = { 'articles' => 'not an array' }
      expect(service.send(:has_valid_api_structure?, json)).to be false
    end
    
    it 'returns true when json is an array of hashes' do
      json = [{ 'title' => 'Test' }]
      expect(service.send(:has_valid_api_structure?, json)).to be true
    end
    
    it 'returns false when json is an empty array' do
      json = []
      expect(service.send(:has_valid_api_structure?, json)).to be false
    end
    
    it 'returns false when json is not a hash or array' do
      json = 'not a hash or array'
      expect(service.send(:has_valid_api_structure?, json)).to be false
    end
  end
end