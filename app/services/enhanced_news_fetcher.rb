require 'feedjira'
require 'open-uri'
require 'nokogiri'
require 'readability'

class EnhancedNewsFetcher
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  ARTICLES_PER_SOURCE = 3
  MIN_CONTENT_LENGTH = 500  # Minimum characters for good summarization
  MAX_CONTENT_SIZE = 2.megabytes  # Prevent memory overflow on 512MB systems
  MAX_FEED_SIZE = 5.megabytes     # Limit RSS feed size

  def initialize(options = {})
    @options = options
    @sources = options[:sources] || []
    @summarize = options.fetch(:summarize, true)  # Default to true for backward compatibility
    @summarizer = @summarize ? AiSummarizerService.new : nil
  end

  def fetch_articles
    all_articles = []
    
    @sources.each do |source|
      begin
        feed = fetch_feed(source.url)
        
        # Get only the 3 most recent entries
        recent_entries = feed.entries
          .sort_by { |entry| entry.published || Time.current }
          .reverse
          .first(ARTICLES_PER_SOURCE)
        
        source_articles = recent_entries.map do |entry|
          if @summarize
            fetch_from_rss_and_summarize(entry, source.name)
          else
            fetch_from_rss_without_summarize(entry, source.name)
          end
        end.compact
        
        if source_articles.present?
          source_articles.each { |a| a[:news_source_id] = source.id }
          all_articles.concat(source_articles)
          update_source_stats(source, 'success', source_articles.length)
        else
          update_source_stats(source, 'no_articles', 0)
        end
      rescue => e
        Rails.logger.error("[NewsFetcher] Error fetching from #{source.name}: #{e.message}")
        update_source_stats(source, 'error', 0)
      end
    end
    
    save_articles(all_articles)
    all_articles
  end

  private

  def fetch_feed(url)
    # Limit feed size to prevent memory overflow
    response = ""
    URI.open(url, "User-Agent" => USER_AGENT, content_length_proc: lambda { |content_length|
      if content_length && content_length > MAX_FEED_SIZE
        raise "Feed too large: #{content_length} bytes (limit: #{MAX_FEED_SIZE})"
      end
    }) do |io|
      response = io.read(MAX_FEED_SIZE)
    end
    
    Feedjira.parse(response)
  rescue => e
    Rails.logger.error("[NewsFetcher] Failed to fetch feed: #{e.message}")
    raise
  end

  def fetch_from_rss_and_summarize(entry, source_name)
    title = entry.title.strip
    url = entry.url || entry.link
    publish_date = entry.published || Time.current
    
    # Try to get full article content first
    content = fetch_full_content_with_readability(url)
    content_source = "Article page"
  
    # Fallback to RSS content if article fetch fails
    if content.blank?
      content = [
        entry.try(:content),
        entry.try(:summary),
        entry.try(:description),
        entry.try(:title)  # Use title as last resort
      ].find { |c| c.present? }
      
      content = strip_html(content.to_s)
      content_source = "RSS feed"
    end
  
    # Clean up content
    content = content.to_s.gsub(/\s+/, ' ').strip
  
    # Always generate summary, even for short content
    summary = if content.present?
      @summarizer.generate_summary(content)
    else
      title
    end
  
    {
      title: title,
      summary: summary || content || title, # Multiple fallbacks
      url: url,
      publish_date: publish_date,
      source: source_name,
      topic: entry.try(:categories)&.first
    }
  end
  
  # Fetch RSS entry without AI summarization (for memory optimization)
  def fetch_from_rss_without_summarize(entry, source_name)
    title = entry.title.strip
    url = entry.url || entry.link
    publish_date = entry.published || Time.current
    
    # Get content from RSS without full article fetch to save memory
    content = [
      entry.try(:content),
      entry.try(:summary),
      entry.try(:description),
      entry.try(:title)
    ].find { |c| c.present? }
    
    content = strip_html(content.to_s).to_s.gsub(/\s+/, ' ').strip
    
    {
      title: title,
      summary: content,  # Use raw content as summary
      url: url,
      publish_date: publish_date,
      source: source_name,
      topic: entry.try(:categories)&.first
    }
  end
  
  def fetch_full_content_with_readability(url)
    return "" if url.blank?
  
    headers = {
      "User-Agent" => USER_AGENT,
      "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "Accept-Language" => "en-US,en;q=0.5",
      "Referer" => "https://www.google.com/"
    }
    
    begin
      # Limit content size to prevent memory overflow
      html = ""
      URI.open(url, headers.merge(
        content_length_proc: lambda { |content_length|
          if content_length && content_length > MAX_CONTENT_SIZE
            Rails.logger.warn("[NewsFetcher] Skipping large page: #{content_length} bytes")
            return ""
          end
        }
      )) do |io|
        html = io.read(MAX_CONTENT_SIZE).force_encoding('UTF-8')
      end
      
      return "" unless html.valid_encoding?
  
      doc = Nokogiri::HTML(html)
      article = Readability::Document.new(
        doc.to_html,
        tags: %w[p img a h1 h2 h3 h4 h5 h6],
        attributes: %w[href src alt],
        remove_empty_nodes: true,
        min_text_length: 25
      ).content
      
      Nokogiri::HTML(article).text.strip
    rescue OpenURI::HTTPError => e
      Rails.logger.error("[NewsFetcher] HTTP error fetching article: #{e.message}")
      ""
    rescue => e
      Rails.logger.error("[NewsFetcher] Error fetching article: #{e.message}")
      ""
    end
  end
  
  def update_source_stats(source, status, article_count)
    source.update(
      last_fetched_at: Time.current,
      last_fetch_status: status,
      last_fetch_article_count: article_count
    )
  rescue => e
    Rails.logger.error("[NewsFetcher] Failed to update stats for #{source.name}: #{e.message}")
  end

  def save_articles(articles)
    new_articles = 0
    existing_articles = 0

    articles.each do |article_data|
      existing = Article.find_by(url: article_data[:url])

      if existing
        existing_articles += 1
        next
      end

      news_source = NewsSource.find(article_data[:news_source_id])
      topic_name = news_source.topic&.name
      
      Article.create!(
        title: article_data[:title],
        summary: article_data[:summary],
        url: article_data[:url],
        publish_date: article_data[:publish_date],
        news_source_id: article_data[:news_source_id],
        source: article_data[:source],
        topic: topic_name
      )
      new_articles += 1
    end

    Rails.logger.info("[NewsFetcher] Articles saved - New: #{new_articles}, Existing: #{existing_articles}, Total: #{articles.length}")
  end

  def strip_html(text)
    return nil if text.blank?
    Nokogiri::HTML(text).text.strip.gsub(/\s+/, ' ')
  end
end