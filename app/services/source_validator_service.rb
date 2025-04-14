require 'net/http'
require 'uri'
require 'rss'

class SourceValidatorService
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
      response = Net::HTTP.get_response(uri)
      
      if response.code.to_i >= 200 && response.code.to_i < 300
        begin
          feed = RSS::Parser.parse(response.body)
          
          # Check if feed is nil
          if feed.nil?
            @errors << "Not a valid RSS feed"
            return false
          end
          
          # Check if it has items/entries
          if feed.items.empty?
            @errors << "RSS feed contains no items"
            return false
          end
          
          # Validate that items have required fields
          sample_item = feed.items.first
          unless has_required_rss_fields?(sample_item)
            @errors << "RSS items are missing required fields"
            return false
          end
          
          true
        rescue RSS::NotWellFormedError
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

  def has_required_rss_fields?(item)
    # Check for required fields in RSS items
    # These are the essential fields for displaying news items
    item.respond_to?(:title) && item.title.present? &&
    item.respond_to?(:link) && item.link.present? &&
    (
      (item.respond_to?(:description) && item.description.present?) ||
      (item.respond_to?(:content) && item.content.present?)
    )
  end
end