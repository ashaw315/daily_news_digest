require 'stopwords'
require 'stopwords/snowball'
require 'ostruct'
require 'open-uri'
require 'nokogiri'
require 'digest/md5'

class NewsFetcher
  attr_reader :sources, :topics, :errors

  def initialize(options = {})
    @sources = options[:sources] || []
    @topics = options[:topics] || default_topics
    @max_articles_per_source = options[:max_articles] || 50
    @detailed_preview = options[:detailed_preview] || false
    @preview_article_count = options[:preview_article_count] || 5
    @errors = []
    @summarizer = AiSummarizerService.new if @detailed_preview
  end

  def fetch_articles
    articles = []
    
    # Try sources in order of priority
    @sources.each do |source|
      # Rails.logger.info("Fetching articles from #{source[:name]} via RSS")
      
      begin
        # Limit to fewer articles for detailed preview
        article_limit = @detailed_preview ? @preview_article_count : @max_articles_per_source
        
        # Get basic article data from the RSS feed
        new_articles = fetch_from_rss(source, article_limit)
        
        # For detailed preview, fetch full content and generate better summaries
        if @detailed_preview
          # Rails.logger.info("Enhancing #{new_articles.length} articles with full content and summaries")
          new_articles = enhance_articles_with_detailed_summaries(new_articles)
        end
        
        # Add source information to articles
        new_articles.each do |article|
          article[:source] = source[:name]
        end
        
        articles.concat(new_articles)
        
        # If we have enough articles, stop fetching
        break if articles.length >= article_limit
      rescue => e
        error_msg = "Error fetching from #{source[:name]}: #{e.message}"
        # Rails.logger.error(error_msg)
        @errors << error_msg
        # Continue to next source on error
      end
    end
    
    # Categorize articles
    categorize_articles(articles)
    
    # Return articles (ensure it's not nil)
    articles || []
  end
  
  private

  def default_topics
    ['politics', 'technology', 'business', 'health', 'entertainment', 'sports', 'science']
  end

  def enhance_articles_with_detailed_summaries(articles)
    enhanced_articles = []
    
    articles.each do |article|
      begin
        # Skip if no URL
        if article[:url].blank?
          # Rails.logger.warn("Article has no URL, skipping content fetch: #{article[:title]}")
          enhanced_articles << article
          next
        end
        
        # Rails.logger.info("Fetching full content for: #{article[:url]}")
        
        # Fetch full content
        full_content = fetch_full_content(article[:url])
        
        if full_content.present? && full_content.length > 200
          # Store the full content
          article[:content] = full_content
          
          # Generate AI summary
          desired_word_count = 250 # or 300, or make this a constant/configurable

          if @summarizer
            # Rails.logger.info("Generating AI summary for: #{article[:title]}")
            summary = @summarizer.summarize(full_content, desired_word_count)
            article[:description] = summary
            # Rails.logger.info("Summary generated: #{summary.split.size} words")
          else
            # Fallback: take the first N words
            words = full_content.split(/\s+/)
            article[:description] = words.take(desired_word_count).join(' ')
            article[:description] += '...' if words.length > desired_word_count
          end
          
          # Rails.logger.info("Successfully processed article: #{article[:title]}")
        else
          # Rails.logger.warn("Failed to fetch meaningful content for: #{article[:url]}")
          # Rails.logger.info("Content length: #{full_content&.length || 0} characters")
        end
      rescue => e
        # Rails.logger.error("Error processing article #{article[:url]}: #{e.message}")
        # Rails.logger.error(e.backtrace.join("\n"))
      end
      
      enhanced_articles << article
    end
    
    enhanced_articles
  end
  
  def generate_ai_summary(content)
    return content if @summarizer.nil?
    
    @summarizer.summarize(content)
  end

  def fetch_full_content(url)
    # Check cache first
    cache_key = "article_content_#{Digest::MD5.hexdigest(url)}"
    cached_content = Rails.cache.read(cache_key)
    
    return cached_content if cached_content.present?
    
    # Fetch content
    content = extract_content_from_url(url)
    
    # Cache the result for 6 hours
    Rails.cache.write(cache_key, content, expires_in: 6.hours) if content.present?
    
    content
  end

  def extract_content_from_url(url)
    begin
      Rails.logger.info("Attempting to extract content from: #{url}")
      
      # Use a realistic user agent to avoid being blocked
      user_agent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
      
      # Create options hash with headers
      options = {
        'User-Agent' => user_agent,
        'Accept' => 'text/html,application/xhtml+xml,application/xml',
        'Accept-Language' => 'en-US,en;q=0.9'
      }
      
      # Open the URL with the specified headers
      html = URI.open(url, options).read
      Rails.logger.info("Successfully fetched HTML from: #{url}")
      
      doc = Nokogiri::HTML(html)
      
      # Clean up the HTML
      doc.css('script, style, nav, header, footer, .ads, .comments, aside, .social-media, .related-articles').remove
      
      # Extract content dynamically
      content = extract_content_dynamically(doc)
      
      # Log content length for debugging
      Rails.logger.info("Extracted content length: #{content.length} characters")
      
      # Clean up the content
      cleaned_content = clean_content(content)
      Rails.logger.info("Cleaned content length: #{cleaned_content.length} characters")
      
      return cleaned_content
    rescue => e
      Rails.logger.error("Error fetching content from #{url}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      "Content unavailable: #{e.message}"
    end
  end

  def extract_content_dynamically(doc)
    # Remove non-content elements
    doc.css('script, style, nav, header, footer, .ads, .comments, aside, .social-media, .related-articles').remove
    
    # Try multiple approaches to find the main content
    
    # 1. Look for article content using common selectors
    content_selectors = [
      'article', '.article', '.post-content', '.entry-content', '.content', 'main', 
      '[itemprop="articleBody"]', '.story-body', '.story-content',
      'section[name="articleBody"]', '.StoryBodyCompanionColumn', '.article-content',
      '.article__content', '.zn-body__paragraph', '.article-body',
      # NYT specific selectors
      '.css-53u6y8', '.css-1r7ky0e', '.g-artboard',
      # WaPo specific selectors
      '.teaser-content', '.article-body',
      # BBC specific selectors
      '.ssrcss-11r1m41-RichTextComponentWrapper', '[data-component="text-block"]',
      # CNN specific selectors
      '.zn-body__paragraph', '.el__article--content',
      # Generic content selectors
      '.story', '.post', '.content-area', '.page-content', '.site-content'
    ]
    
    # Try each selector
    content_selectors.each do |selector|
      elements = doc.css("#{selector} p")
      if elements.length >= 3  # At least 3 paragraphs to be considered valid content
        return elements.map(&:text).join("\n\n")
      end
    end
    
    # 2. If no specific container found, look for the largest cluster of paragraphs
    paragraphs = doc.css('p')
    
    if paragraphs.length >= 3
      # Find the parent element that contains the most paragraphs
      parent_counts = Hash.new(0)
      
      paragraphs.each do |p|
        parent = p.parent
        parent_counts[parent] += 1
      end
      
      # Get the parent with the most paragraphs
      best_parent = parent_counts.max_by { |_, count| count }
      
      if best_parent && best_parent[1] >= 3
        return best_parent[0].css('p').map(&:text).join("\n\n")
      end
      
      # If no good parent found, just use all paragraphs
      return paragraphs.map(&:text).join("\n\n")
    end
    
    # 3. Last resort: just get all text from the body
    body_text = doc.css('body').text.strip.gsub(/\s+/, ' ')
    return body_text
  end
  
  def clean_content(content)
    return "" if content.blank?
    
    # Remove common artifacts
    cleaned = content.gsub(/Advertisement.*?\n/i, '')
                    .gsub(/Credit.*?\n/i, '')
                    .gsub(/Supported by.*?\n/i, '')
                    .gsub(/Photo by.*?\n/i, '')
                    .gsub(/Image by.*?\n/i, '')
                    .gsub(/\[.*?\]/, '') # Remove anything in square brackets
                    .gsub(/\(.*?\)/, '') # Remove anything in parentheses
    
    # Remove lines that are too short (likely not part of the main content)
    lines = cleaned.split("\n").reject { |line| line.strip.length < 20 }
    
    # Join back together
    cleaned = lines.join("\n")
    
    # Remove excessive whitespace
    cleaned.gsub(/\s+/, ' ').strip
  end
  
  def fetch_from_rss(source, limit = nil)
    xml = HTTParty.get(source[:url]).body
    feed = Feedjira.parse(xml)
    
    # Apply limit if specified
    entries = limit ? feed.entries.take(limit) : feed.entries
    
    entries.map do |entry|
      {
        title: entry.title,
        description: entry.summary || entry.content || '',
        url: entry.url || entry.link,
        published_at: entry.published || Time.now,
        topic: nil,  # Will be categorized later
        content: nil # Will be fetched later
      }.with_indifferent_access
    end
  end
  
  def categorize_articles(articles)
    return articles if articles.blank? || @topics.blank?
    
    articles.each do |article|
      next if article[:topic].present?
      
      # Combine title and description for better context
      text = "#{article[:title]} #{article[:description]}"
      
      # Create a prompt for the AI
      prompt = "Classify the following news article into exactly one of these categories: #{@topics.join(', ')}.\n\nArticle: #{text}\n\nCategory:"
      
      begin
        response = OpenAI::Client.new.chat(
          parameters: {
            model: "gpt-3.5-turbo",
            messages: [{ role: "user", content: prompt }],
            temperature: 0.3, # Lower temperature for more consistent categorization
            max_tokens: 10
          }
        )
        
        # Extract the topic from the response
        predicted_topic = response.dig("choices", 0, "message", "content")&.strip&.downcase
        
        # Assign the topic if it's in our list of valid topics
        article[:topic] = predicted_topic if @topics.include?(predicted_topic)
      rescue => e
        Rails.logger.error("Error categorizing article: #{e.message}")
        # Skip this article if classification fails
        next
      end
    end
    
    articles
  end
  
  # Extract keywords from text
  def extract_keywords(text, count = 5)
    # Common English stopwords
    stopwords = %w[
      a about above after again against all am an and any are aren't as at
      be because been before being below between both but by
      can't cannot could couldn't
      did didn't do does doesn't doing don't down during
      each
      few for from further
      had hadn't has hasn't have haven't having he he'd he'll he's her here here's hers herself him himself his how how's
      i i'd i'll i'm i've if in into is isn't it it's its itself
      let's
      me more most mustn't my myself
      no nor not
      of off on once only or other ought our ours ourselves out over own
      same shan't she she'd she'll she's should shouldn't so some such
      than that that's the their theirs them themselves then there there's these they they'd they'll they're they've this those through to too
      under until up
      very
      was wasn't we we'd we'll we're we've were weren't what what's when when's where where's which while who who's whom why why's with won't would wouldn't
      you you'd you'll you're you've your yours yourself yourselves
    ]
    
    # Process text: convert to lowercase, remove punctuation, split into words
    words = text.downcase.gsub(/[^\w\s]/, '').split
    
    # Filter out stopwords and words shorter than 3 characters
    filtered_words = words.reject { |word| stopwords.include?(word) || word.length < 3 }
    
    # Count word frequencies
    word_counts = Hash.new(0)
    filtered_words.each { |word| word_counts[word] += 1 }
    
    # Return top N keywords (sorted by frequency)
    word_counts.sort_by { |_word, count| -count }.first(count).to_h
  end
  
  # Database Methods
  def save_articles(articles)
    articles.each do |article_data|
      # Skip if article already exists
      next if Article.exists?(url: article_data[:url])
      
      # Find the news source by name
      news_source = NewsSource.find_by(name: article_data[:source])
      next unless news_source # Skip if we can't find the news source
      
      # Create new article
      Article.create!(
        title: article_data[:title],
        summary: article_data[:description],
        url: article_data[:url],
        publish_date: article_data[:published_at],
        news_source: news_source,  # Use the news source association
        topic: article_data[:topic]
      )
    end
  end
end