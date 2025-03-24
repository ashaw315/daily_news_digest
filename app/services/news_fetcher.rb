require 'stopwords'
require 'stopwords/snowball'

class NewsFetcher
  attr_reader :sources, :topics

  def initialize(options = {})
    @sources = options[:sources] || []
    @topics = options[:topics] || default_topics
    @max_articles_per_source = options[:max_articles] || 50
    @robots_txt_cache = {}
  end

  def fetch_articles
    articles = []
    
    # Try sources in order of priority
    @sources.each do |source|
      Rails.logger.info("Fetching articles from #{source[:name]} via #{source[:type]}")
      
      begin
        new_articles = case source[:type]
                       when :rss
                         fetch_from_rss(source)
                       when :api
                         fetch_from_api(source)
                       when :scrape
                         fetch_from_scraper(source)
                       else
                         []
                       end
        
        # Add source information to articles
        new_articles.each do |article|
          article.source = source[:name]
        end
        
        articles.concat(new_articles)
        
        # If we have enough articles, stop fetching
        break if articles.length >= @max_articles_per_source
      rescue => e
        Rails.logger.error("Error fetching from #{source[:name]}: #{e.message}")
        # Continue to next source on error
      end
    end
    
    # Categorize articles
    categorize_articles(articles)
    
    # Save articles to database
    save_articles(articles)
    
    articles
  end
  
  private
  
  def default_topics
    ['politics', 'business', 'technology', 'science', 'health', 'sports', 'entertainment', 'art&design']
  end
  
  # RSS Feed Methods
  def fetch_from_rss(source)
    xml = HTTParty.get(source[:url]).body
    feed = Feedjira.parse(xml)
    
    feed.entries.map do |entry|
      OpenStruct.new(
        title: entry.title,
        description: entry.summary || entry.content || '',
        url: entry.url || entry.link,
        published_at: entry.published || Time.now,
        topic: nil  # Will be categorized later
      )
    end
  end
  
  # API Methods
  def fetch_from_api(source)
    url = source[:url]
    
    begin
      response = HTTParty.get(url)
      
      if response.code == 200
        # Parse the JSON response
        data = JSON.parse(response.body)
        
        # Extract articles from the response
        # Assuming the API returns an array of articles under the 'articles' key
        if data['articles'].is_a?(Array)
          return data['articles'].map do |article_data|
            # Create an OpenStruct to match the format used by other methods
            OpenStruct.new(
              title: article_data['title'],
              description: article_data['description'],
              url: article_data['url'],
              published_at: article_data['publishedAt'] ? Time.parse(article_data['publishedAt']) : Time.now
            )
          end
        end
      end
      
      # Return empty array if response is not successful or doesn't contain articles
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
      # Move the binding.pry after the response is assigned
      response = HTTParty.get(url)
      binding.pry
      
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

          binding.pry
          
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
  
  # Categorization Methods
  def categorize_articles(articles)
    # Initialize classifier
    classifier = ClassifierReborn::Bayes.new(*@topics)
    
    # Train classifier with some sample data
    train_classifier(classifier)
    
    # Categorize each article
    articles.each do |article|
      text = "#{article.title} #{article.description}"
      article.topic = classifier.classify(text)
    end
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