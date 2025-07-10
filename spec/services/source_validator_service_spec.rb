require 'rails_helper'
require 'webmock/rspec'

RSpec.describe SourceValidatorService do
  let(:rss_source) { build(:news_source, format: 'rss', url: 'https://example.com/rss.xml', settings: {}) }

  describe '#validate' do
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
        expect(service.errors).to include("Not a valid RSS feed or HTML page")
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
  end

  describe '#has_required_fields?' do
    let(:service) { described_class.new(rss_source) }
    
    it 'returns true when all required fields are present' do
      title = double('Title')
      allow(title).to receive(:present?).and_return(true)
      
      link = double('Link')
      allow(link).to receive(:present?).and_return(true)
      
      description = double('Description')
      allow(description).to receive(:present?).and_return(true)
      
      item = double('RSS Item')
      allow(item).to receive(:title).and_return(title)
      allow(item).to receive(:url).and_return(nil)
      allow(item).to receive(:link).and_return(link)
      allow(item).to receive(:content).and_return(nil)
      allow(item).to receive(:summary).and_return(nil)
      allow(item).to receive(:description).and_return(description)
      
      expect(service.send(:has_required_fields?, item)).to be true
    end
    
    it 'returns false when title is missing' do
      title = double('Title')
      allow(title).to receive(:present?).and_return(false)
      
      link = double('Link')
      allow(link).to receive(:present?).and_return(true)
      
      description = double('Description')
      allow(description).to receive(:present?).and_return(true)
      
      item = double('RSS Item')
      allow(item).to receive(:title).and_return(title)
      allow(item).to receive(:url).and_return(nil)
      allow(item).to receive(:link).and_return(link)
      allow(item).to receive(:content).and_return(nil)
      allow(item).to receive(:summary).and_return(nil)
      allow(item).to receive(:description).and_return(description)
      
      expect(service.send(:has_required_fields?, item)).to be false
    end
    
    it 'returns false when link is missing' do
      title = double('Title')
      allow(title).to receive(:present?).and_return(true)
      
      url = double('URL')
      allow(url).to receive(:present?).and_return(false)
      
      link = double('Link')
      allow(link).to receive(:present?).and_return(false)
      
      description = double('Description')
      allow(description).to receive(:present?).and_return(true)
      
      item = double('RSS Item')
      allow(item).to receive(:title).and_return(title)
      allow(item).to receive(:url).and_return(url)
      allow(item).to receive(:link).and_return(link)
      allow(item).to receive(:content).and_return(nil)
      allow(item).to receive(:summary).and_return(nil)
      allow(item).to receive(:description).and_return(description)
      
      expect(service.send(:has_required_fields?, item)).to be false
    end
    
    it 'returns false when both description and content are missing' do
      title = double('Title')
      allow(title).to receive(:present?).and_return(true)
      
      link = double('Link')
      allow(link).to receive(:present?).and_return(true)
      
      description = double('Description')
      allow(description).to receive(:present?).and_return(false)
      
      content = double('Content')
      allow(content).to receive(:present?).and_return(false)
      
      summary = double('Summary')
      allow(summary).to receive(:present?).and_return(false)
      
      item = double('RSS Item')
      allow(item).to receive(:title).and_return(title)
      allow(item).to receive(:url).and_return(nil)
      allow(item).to receive(:link).and_return(link)
      allow(item).to receive(:content).and_return(content)
      allow(item).to receive(:summary).and_return(summary)
      allow(item).to receive(:description).and_return(description)
      
      expect(service.send(:has_required_fields?, item)).to be false
    end
    
    it 'returns true when description is missing but content is present' do
      title = double('Title')
      allow(title).to receive(:present?).and_return(true)
      
      link = double('Link')
      allow(link).to receive(:present?).and_return(true)
      
      description = double('Description')
      allow(description).to receive(:present?).and_return(false)
      
      content = double('Content')
      allow(content).to receive(:present?).and_return(true)
      
      item = double('RSS Item')
      allow(item).to receive(:title).and_return(title)
      allow(item).to receive(:url).and_return(nil)
      allow(item).to receive(:link).and_return(link)
      allow(item).to receive(:content).and_return(content)
      allow(item).to receive(:summary).and_return(nil)
      allow(item).to receive(:description).and_return(description)
      
      expect(service.send(:has_required_fields?, item)).to be true
    end
  end
end