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
    @robots_txt_cache = {}
    @errors = []
    @summarizer = AiSummarizerService.new if @detailed_preview
  end

  def fetch_articles
    articles = []
    
    # Try sources in order of priority
    @sources.each do |source|
      Rails.logger.info("Fetching articles from #{source[:name]} via #{source[:type]}")
      
      begin
        # Limit to fewer articles for detailed preview
        article_limit = @detailed_preview ? @preview_article_count : @max_articles_per_source
        
        # Get basic article data from the source
        new_articles = case source[:type].to_sym
                       when :rss
                         fetch_from_rss(source, article_limit)
                       when :api
                         fetch_from_api(source, article_limit)
                       when :scrape
                         fetch_from_scraper(source, article_limit)
                       else
                         @errors << "Unsupported source type: #{source[:type]}"
                         []
                       end
        
        # For detailed preview, fetch full content and generate better summaries
        if @detailed_preview
          Rails.logger.info("Enhancing #{new_articles.length} articles with full content and summaries")
          new_articles = enhance_articles_with_detailed_summaries(new_articles)
        end
        
        # Add source information to articles
        new_articles.each do |article|
          article[:source] = source[:name]  # Use hash syntax instead of dot notation
        end
        
        articles.concat(new_articles)
        
        # If we have enough articles, stop fetching
        break if articles.length >= article_limit
      rescue => e
        error_msg = "Error fetching from #{source[:name]}: #{e.message}"
        Rails.logger.error(error_msg)
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
        if article[:url].blank?  # Use hash syntax
          Rails.logger.warn("Article has no URL, skipping content fetch: #{article[:title]}")
          enhanced_articles << article
          next
        end
        
        Rails.logger.info("Fetching full content for: #{article[:url]}")
        
        # Fetch full content
        full_content = fetch_full_content(article[:url])
        
        if full_content.present? && full_content.length > 200
          # Store the full content
          article[:content] = full_content  # Use hash syntax
          
          # Generate AI summary
          if @summarizer
            Rails.logger.info("Generating AI summary for: #{article[:title]}")
            summary = @summarizer.summarize(full_content)
            
            # Explicitly update the description
            article[:description] = summary  # Use hash syntax
            
            Rails.logger.info("Summary generated: #{summary.truncate(100)}")
          else
            # If no AI summarizer, create a simple summary
            article[:description] = full_content.split(/\s+/).take(200).join(' ') + '...'  # Use hash syntax
          end
          
          Rails.logger.info("Successfully processed article: #{article[:title]}")
        else
          Rails.logger.warn("Failed to fetch meaningful content for: #{article[:url]}")
          Rails.logger.info("Content length: #{full_content&.length || 0} characters")
        end
      rescue => e
        Rails.logger.error("Error processing article #{article[:url]}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
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

  # Update the API fetching method to respect the limit
  def fetch_from_api(source, limit = nil)
    url = source[:url]
    
    begin
      response = HTTParty.get(url)
      
      if response.code == 200
        # Parse the JSON response
        data = JSON.parse(response.body)
        
        # Extract articles from the response
        if data['articles'].is_a?(Array)
          articles = data['articles'].map do |article_data|
            OpenStruct.new(
              title: article_data['title'],
              description: article_data['description'],
              url: article_data['url'],
              published_at: article_data['publishedAt'] ? Time.parse(article_data['publishedAt']) : Time.now
            )
          end
          
          # Apply limit if specified
          return limit ? articles.take(limit) : articles
        end
      end
      
      []
    rescue => e
      Rails.logger.error("Error fetching from API #{url}: #{e.message}")
      []
    end
  end
  
    # Web Scraping Methods
  def fetch_from_scraper(source)
    url = source[:url]
    selectors = source[:selectors] || {}
    
    if !scraping_allowed?(url)
      Rails.logger.info("Scraping not allowed for #{url} according to robots.txt")
      return []
    end
    
    begin
      response = HTTParty.get(url)
      
      if response.code == 200
        doc = Nokogiri::HTML(response.body)
        
        # Extract articles using the provided selectors
        article_selector = selectors[:article] || 'article'
        title_selector = selectors[:title] || 'h2'
        link_selector = selectors[:link] || 'a'
        description_selector = selectors[:description] || 'p'
        date_selector = selectors[:date] || 'time'
        
        articles = doc.css(article_selector).map do |article_element|
          # Extract title
          title_element = article_element.css(title_selector).first
          title = title_element&.text&.strip
          
          # Extract link
          link_element = article_element.css(link_selector).first
          url = link_element&.attributes&.[]('href')&.value
          
          # Make relative URLs absolute
          if url && !url.start_with?('http')
            uri = URI.parse(source[:url])
            base_url = "#{uri.scheme}://#{uri.host}"
            url = "#{base_url}#{url}"
          end
          
          # Extract description
          description_element = article_element.css(description_selector).first
          description = description_element&.text&.strip
          
          # Extract date
          date_element = article_element.css(date_selector).first
          published_at = nil
          
          if date_element
            # Try to parse the date from the datetime attribute
            datetime = date_element.attributes['datetime']&.value
            published_at = datetime ? Time.parse(datetime) : Time.now
          else
            published_at = Time.now
          end
          
          # Create an article object if we have the minimum required fields
          if title && url
            OpenStruct.new(
              title: title,
              description: description,
              url: url,
              published_at: published_at,
              source: source[:name]
            )
          else
            nil
          end
        end.compact
        
        return articles
      end
      
      []
    rescue => e
      Rails.logger.error("Error scraping #{url}: #{e.message}")
      []
    end
  end
  
  def scraping_allowed?(url)
    begin
      uri = URI.parse(url)
      base_url = "#{uri.scheme}://#{uri.host}"
      path = uri.path.empty? ? "/" : uri.path
      
      # Check cache first
      cache_key = "#{base_url}#{path}"
      return @robots_txt_cache[cache_key] if @robots_txt_cache.key?(cache_key)
      
      # If robotstxt-parser is available, use it
      if defined?(Robotstxt)
        robots_txt_url = "#{base_url}/robots.txt"
        
        # Check if we've already fetched the robots.txt for this domain
        unless @robots_txt_cache.key?("#{base_url}/robots.txt")
          response = HTTParty.get(robots_txt_url)
          
          if response.code == 200
            # Cache the robots.txt content
            @robots_txt_cache["#{base_url}/robots.txt"] = response.body
          else
            # If no robots.txt, cache that fact
            @robots_txt_cache["#{base_url}/robots.txt"] = nil
          end
        end
        
        # Get the cached robots.txt content
        robots_txt = @robots_txt_cache["#{base_url}/robots.txt"]
        
        if robots_txt
          # Parse the robots.txt and check if the path is allowed
          parser = Robotstxt::Parser.new(robots_txt)
          allowed = parser.allowed?('*', path)
          
          # Cache the result for this path
          @robots_txt_cache[cache_key] = allowed
          
          return allowed
        else
          # If no robots.txt, assume allowed
          @robots_txt_cache[cache_key] = true
          return true
        end
      else
        # If gem not available, assume allowed
        @robots_txt_cache[cache_key] = true
        return true
      end
    rescue => e
      Rails.logger.error("Error checking robots.txt for #{url}: #{e.message}")
      # Assume not allowed on error to be safe
      false
    end
  end
  
  def categorize_articles(articles)
    return articles if articles.blank?
    
    # Skip categorization if no topics defined
    return articles if @topics.blank?
    
    # Create a hash of topic => keywords
    topic_keywords = {}
    @topics.each do |topic|
      # Convert topic to lowercase for case-insensitive matching
      keywords = topic.downcase.split(/[,\s]+/).reject(&:blank?)
      topic_keywords[topic] = keywords if keywords.any?
    end
    
    # Skip if no keywords defined
    return articles if topic_keywords.empty?
    
    # Get stopwords for filtering
    stopwords = Stopwords::Snowball::Filter.new("en").stopwords
    
    articles.each do |article|
      # Skip if already categorized
      next if article[:topic].present?
      
      # Get text to analyze (title + description)
      text = "#{article[:title]} #{article[:description]}".downcase
      
      # Tokenize and filter stopwords
      words = text.split(/[^\w]/).reject(&:blank?).reject { |w| stopwords.include?(w) }
      
      # Count occurrences of topic keywords
      topic_scores = {}
      topic_keywords.each do |topic, keywords|
        score = 0
        keywords.each do |keyword|
          score += words.count { |word| word.include?(keyword) }
        end
        topic_scores[topic] = score if score > 0
      end
      
      # Assign the topic with the highest score
      if topic_scores.any?
        article[:topic] = topic_scores.max_by { |_, score| score }.first
      end
    end
    
    articles
  end
  
  def train_classifier(classifier)
    # Sample training data for each topic
    {
      'politics' => [
        'government election president vote democracy congress senate parliament',
        'political party campaign ballot democratic republican liberal conservative',
        'policy legislation law bill amendment constitution court supreme',
        'foreign affairs diplomacy international relations treaty sanctions'
      ],
      'business' => [
        'economy market stock shares investment profit loss',
        'company corporation business CEO executive industry sector',
        'trade commerce retail consumer product service',
        'finance bank loan interest rate mortgage debt credit'
      ],
      'technology' => [
        'computer software hardware internet web digital online',
        'app application mobile smartphone device gadget',
        'data algorithm AI artificial intelligence machine learning',
        'cybersecurity hack breach encryption privacy'
      ],
      'science' => [
        'research study experiment laboratory scientist',
        'discovery innovation breakthrough development',
        'physics chemistry biology astronomy space',
        'environment climate ecosystem sustainability'
      ],
      'health' => [
        'medical doctor hospital patient treatment therapy',
        'disease illness condition symptom diagnosis cure',
        'medicine drug pharmaceutical vaccine immunity',
        'wellness fitness nutrition diet exercise'
      ],
      'sports' => [
        'game match tournament championship competition',
        'team player coach athlete score win lose',
        'football soccer basketball baseball hockey tennis golf',
        'olympic medal record performance stadium'
      ],
      'entertainment' => [
        'movie film actor actress director cinema',
        'music song artist band concert album',
        'television show series episode streaming',
        'celebrity star award festival performance'
      ]
    }.each do |topic, examples|
      examples.each do |example|
        classifier.train(topic, example)
      end
    end
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
      next if Article.exists?(url: article_data.url)
      
      # Create new article
      Article.create!(
        title: article_data.title,
        summary: article_data.description,
        url: article_data.url,
        publish_date: article_data.published_at,
        source: article_data.source,
        topic: article_data.topic
      )
    end
  end
end 