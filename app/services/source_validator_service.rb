require 'net/http'
require 'uri'
require 'nokogiri'
require 'feedjira'
require_relative '../helpers/html_article_extractor'

class SourceValidatorService
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  
  attr_reader :source, :errors

  def initialize(source)
    @source = source
    @errors = []
  end

  def validate
    validate_feed_or_page
  end

  private

  def validate_feed_or_page
    begin
      uri = URI.parse(source.url)
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = USER_AGENT
      request["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,application/rss+xml,*/*;q=0.8"
      
      response = http.request(request)
      
      if response.code.to_i >= 200 && response.code.to_i < 300
        content_type = response['Content-Type']&.downcase || ''
        
        if content_type.include?('xml') || content_type.include?('rss')
          validate_rss_feed(response.body)
        else
          validate_html_page(response.body)
        end
      else
        @errors << "HTTP request failed with status code: #{response.code}"
        false
      end
    rescue URI::InvalidURIError
      @errors << "Invalid URL format"
      false
    rescue => e
      @errors << "Error validating source: #{e.message}"
      false
    end
  end

  def validate_rss_feed(body)
    begin
      # Make sure we're working with a string
      raw_body = body.to_s
      
      feed = Feedjira.parse(raw_body)
      
      if feed.nil?
        @errors << "Feedjira returned nil - not a valid feed"
        return false
      end
      
      if feed.entries.empty?
        @errors << "RSS feed contains no items"
        return false
      end
      
      sample_entry = feed.entries.first
      unless has_required_fields?(sample_entry)
        @errors << "RSS items are missing required fields"
        return false
      end
      
      true
    rescue Feedjira::NoParserAvailable
      # If RSS parsing fails, try HTML parsing as fallback
      if validate_html_page(body)
        @source.format = 'html'
        return true
      end
      @errors << "Not a valid RSS feed or HTML page"
      false
    rescue => e
      @errors << "Error parsing RSS: #{e.message}"
      false
    end
  end

  def validate_html_page(body)
    begin
      extractor = HtmlArticleExtractor.new(body)
      
      if extractor.has_valid_articles?
        @source.format = 'html' if @source.format != 'rss'
        true
      else
        @errors << "No valid articles found on page"
        false
      end
    rescue => e
      @errors << "Error parsing HTML page: #{e.message}"
      false
    end
  end

  def has_required_fields?(entry)
    entry.title.present? &&
    (entry.url.present? || entry.link.present?) &&
    (entry.content.present? || entry.summary.present? || entry.description.present?)
  end
end