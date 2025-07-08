require 'net/http'
require 'uri'
require 'feedjira'  # Change to use Feedjira instead of RSS

class SourceValidatorService
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  
  attr_reader :source, :errors

  def initialize(source)
    @source = source
    @errors = []
  end

  def validate
    validate_rss
  end

  private

  def validate_rss
    begin
      uri = URI.parse(source.url)
      
      # Create HTTP client with proper configuration
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      
      # Create request with proper headers
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = USER_AGENT
      request["Accept"] = "application/rss+xml, application/xml, application/atom+xml, text/xml, */*"
      
      response = http.request(request)
      
      if response.code.to_i >= 200 && response.code.to_i < 300
        begin
          # Use Feedjira instead of RSS::Parser
          feed = Feedjira.parse(response.body)
          
          # Check if feed has entries
          if feed.entries.empty?
            @errors << "RSS feed contains no items"
            return false
          end
          
          # Validate that entries have required fields
          sample_entry = feed.entries.first
          unless has_required_fields?(sample_entry)
            @errors << "RSS items are missing required fields"
            return false
          end
          
          true
        rescue Feedjira::NoParserAvailable
          @errors << "Not a valid RSS feed"
          false
        rescue => e
          @errors << "Error parsing RSS: #{e.message}"
          false
        end
      else
        @errors << "HTTP request failed with status code: #{response.code}"
        false
      end
    rescue URI::InvalidURIError
      @errors << "Invalid URL format"
      false
    rescue => e
      @errors << "Error validating RSS feed: #{e.message}"
      false
    end
  end

  def has_required_fields?(entry)
    # Check for required fields in Feedjira entries
    entry.title.present? &&
    (entry.url.present? || entry.link.present?) &&
    (
      entry.content.present? ||
      entry.summary.present? ||
      entry.description.present?
    )
  end

  # Alias method for backward compatibility with tests
  def has_required_rss_fields?(item)
    # This method is designed to work with test doubles and basic RSS items
    return false unless item.title.present?
    return false unless (item.respond_to?(:link) && item.link.present?)
    
    # Check if either description or content is present
    has_description = item.respond_to?(:description) && item.description.present?
    has_content = item.respond_to?(:content) && item.content.present?
    
    has_description || has_content
  end
end