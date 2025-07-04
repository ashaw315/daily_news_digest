require 'feedjira'
require 'open-uri'
require 'nokogiri'
require 'readability'

class EnhancedNewsFetcher
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  ARTICLES_PER_SOURCE = 3
  MIN_CONTENT_LENGTH = 500  # Minimum characters for good summarization

  def initialize(options = {})
    @options = options
    @sources = options[:sources] || []
    @summarizer = AiSummarizerService.new
  end

  def fetch_articles
    all_articles = []
    
    puts "\n=== Starting Article Fetch ==="
    @sources.each do |source|
      begin
        puts "Fetching from: #{source.name}"
        feed = fetch_feed(source.url)
        
        # Get only the 3 most recent entries
        recent_entries = feed.entries
          .sort_by { |entry| entry.published || Time.current }
          .reverse
          .first(ARTICLES_PER_SOURCE)
        
        source_articles = recent_entries.map do |entry|
          fetch_from_rss_and_summarize(entry, source.name)
        end.compact
        
        puts "  - Got #{source_articles.length} articles from #{source.name}"
        puts "  - Article titles:"
        source_articles.each { |a| puts "    * #{a[:title]}" }
        
        if source_articles.present?
          source_articles.each { |a| a[:news_source_id] = source.id }
          all_articles.concat(source_articles)
          update_source_stats(source, 'success', source_articles.length)
        else
          puts "  - No articles found for #{source.name}"
          update_source_stats(source, 'no_articles', 0)
        end
      rescue => e
        puts "  - Error with #{source.name}: #{e.message}"
        update_source_stats(source, 'error', 0)
      end
    end
  
    puts "\n=== Article Fetch Summary ==="
    @sources.each do |source|
      count = all_articles.count { |a| a[:news_source_id] == source.id }
      puts "#{source.name}: #{count} articles"
    end
    puts "Total articles fetched: #{all_articles.length}"
    puts "=========================\n"
    
    save_articles(all_articles)
    all_articles
  end

  private

  def fetch_feed(url)
    response = URI.open(url, "User-Agent" => USER_AGENT).read
    Feedjira.parse(response)
  rescue => e
    puts "  - Failed to fetch feed: #{e.message}"
    raise
  end

  def fetch_from_rss_and_summarize(entry, source_name)
    title = entry.title.strip
    url = entry.url || entry.link
    publish_date = entry.published || Time.current
    
    puts "\n=== Processing Article ==="
    puts "Title: #{title}"
    puts "URL: #{url}"
    puts "Source: #{source_name}"
    
    # Try to get full article content first
    content = fetch_full_content_with_readability(url)
    content_source = "Article page"
  
    # Fallback to RSS content if article fetch fails
    if content.blank?
      # Try all possible RSS content fields
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
    
    puts "Content source: #{content_source}"
    puts "Content length: #{content.length} chars"
    puts "Content preview: #{content[0..200]}..." if content.present?
  
    # Always generate summary, even for short content
    summary = if content.present?
      puts "Generating AI summary from #{content.length} chars..."
      @summarizer.generate_summary(content)
    else
      puts "No content available, using title"
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
  
  def fetch_full_content_with_readability(url)
    return "" if url.blank?
  
    headers = {
      "User-Agent" => USER_AGENT,
      "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "Accept-Language" => "en-US,en;q=0.5",
      "Referer" => "https://www.google.com/"
    }
    
    begin
      html = URI.open(url, headers).read.force_encoding('UTF-8')
      return "" unless html.valid_encoding?
  
      doc = Nokogiri::HTML(html)
      article = Readability::Document.new(
        doc.to_html,
        tags: %w[p img a h1 h2 h3 h4 h5 h6],
        attributes: %w[href src alt],
        remove_empty_nodes: true,
        min_text_length: 25
      ).content
      
      content = Nokogiri::HTML(article).text.strip
      puts "  * Successfully fetched article content (#{content.length} chars)"
      content
    rescue OpenURI::HTTPError => e
      puts "  * HTTP error fetching article: #{e.message}"
      ""
    rescue => e
      puts "  * Error fetching article: #{e.message}"
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
    puts "  - Failed to update stats for #{source.name}: #{e.message}"
  end

  def save_articles(articles)
    new_articles = 0
    existing_articles = 0

    articles.each do |article_data|
      existing = Article.find_by(url: article_data[:url])

      if existing
        puts "  - Skipping existing article: #{article_data[:title]}"
        existing_articles += 1
        next
      end

      news_source = NewsSource.find(article_data[:news_source_id])
      topic_name = news_source.topic&.name # Assuming Topic model has a 'name' field
      
      Article.create!(
        title: article_data[:title],
        summary: article_data[:summary],
        url: article_data[:url],
        publish_date: article_data[:publish_date],
        news_source_id: article_data[:news_source_id],
        source: article_data[:source],
        topic: topic_name  # Use the associated Topic's name
      )
      puts "  - Saved new article: #{article_data[:title]}"
      new_articles += 1
    end

    puts "\n=== Article Save Summary ==="
    puts "New articles saved: #{new_articles}"
    puts "Existing articles skipped: #{existing_articles}"
    puts "Total processed: #{articles.length}"
    puts "========================="
  end

  def strip_html(text)
    return nil if text.blank?
    Nokogiri::HTML(text).text.strip.gsub(/\s+/, ' ')
  end
end