class NewsFetcher
  attr_reader :sources, :topics

  def initialize(options = {})
    @sources = options[:sources] || default_sources
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
  
  def default_sources

    # NEEDS TO BE FIXED!!!
    [
      # RSS Feeds (highest priority)
      { name: 'BBC News', type: :rss, url: 'http://feeds.bbci.co.uk/news/rss.xml' },
      { name: 'Reuters', type: :rss, url: 'http://feeds.reuters.com/reuters/topNews' },
      { name: 'NPR', type: :rss, url: 'https://feeds.npr.org/1001/rss.xml' },
      
      # API Sources (medium priority)
      { name: 'NewsAPI', type: :api, service: :news_api, api_key: ENV['NEWS_API_KEY'] },
      { name: 'Mediastack', type: :api, service: :mediastack, api_key: ENV['MEDIASTACK_API_KEY'] },
      
      # Scraping Sources (lowest priority)
      { name: 'The Guardian', type: :scrape, url: 'https://www.theguardian.com/world' },
      { name: 'Washington Post', type: :scrape, url: 'https://www.washingtonpost.com/' }
    ]
  end
  
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
    case source[:service]
    when :news_api
      fetch_from_news_api(source)
    when :mediastack
      fetch_from_mediastack(source)
    else
      []
    end
  end
  
  def fetch_from_news_api(source)
    newsapi = News.new(source[:api_key])
    
    # Get top headlines
    response = newsapi.get_top_headlines(
      language: 'en',
      pageSize: @max_articles_per_source
    )
    
    response.articles.map do |article|
      OpenStruct.new(
        title: article.title,
        description: article.description || '',
        url: article.url,
        published_at: article.publishedAt || Time.now,
        topic: nil  # Will be categorized later
      )
    end
  end
  
  def fetch_from_mediastack(source)
    client = Mediastack::Client.new(source[:api_key])
    
    response = client.news(
      languages: 'en',
      limit: @max_articles_per_source
    )
    
    response['data'].map do |article|
      OpenStruct.new(
        title: article['title'],
        description: article['description'] || '',
        url: article['url'],
        published_at: article['published_at'] ? Time.parse(article['published_at']) : Time.now,
        topic: nil  # Will be categorized later
      )
    end
  end
  
  # Web Scraping Methods
  def fetch_from_scraper(source)
    url = source[:url]
    
    # Check if scraping is allowed (if robotstxt-parser is available)
    if defined?(Robotstxt) && !scraping_allowed?(url)
      Rails.logger.warn("Scraping not allowed for #{url} according to robots.txt")
      return []
    end
    
    response = HTTParty.get(url)
    doc = Nokogiri::HTML(response.body)
    
    articles = []
    
    # Different scraping logic for different sites
    case source[:name]
    when 'The Guardian'
      doc.css('div.fc-item__container').each do |article_div|
        title_element = article_div.at_css('h3.fc-item__title')
        link_element = article_div.at_css('a.fc-item__link')
        
        next unless title_element && link_element
        
        articles << OpenStruct.new(
          title: title_element.text.strip,
          description: '',  # No description available from list view
          url: link_element['href'],
          published_at: Time.now,  # No date available from list view
          topic: nil  # Will be categorized later
        )
      end
    when 'Washington Post'
      doc.css('div.story-headline').each do |headline_div|
        title_element = headline_div.at_css('h2, h3')
        link_element = headline_div.at_css('a')
        
        next unless title_element && link_element
        
        articles << OpenStruct.new(
          title: title_element.text.strip,
          description: '',  # No description available from list view
          url: link_element['href'],
          published_at: Time.now,  # No date available from list view
          topic: nil  # Will be categorized later
        )
      end
    end
    
    articles.take(@max_articles_per_source)
  end
  
  def scraping_allowed?(url)
    begin
      uri = URI.parse(url)
      base_url = "#{uri.scheme}://#{uri.host}"
      
      # Check cache first
      return @robots_txt_cache[base_url] if @robots_txt_cache.key?(base_url)
      
      # If robotstxt-parser is available, use it
      if defined?(Robotstxt)
        robots_txt_url = "#{base_url}/robots.txt"
        response = HTTParty.get(robots_txt_url)
        
        if response.code == 200
          parser = Robotstxt::Parser.new(response.body)
          allowed = parser.allowed?('*', uri.path)
        else
          # If no robots.txt, assume allowed
          allowed = true
        end
      else
        # If gem not available, assume allowed
        allowed = true
      end
      
      # Cache the result
      @robots_txt_cache[base_url] = allowed
      
      allowed
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
    # Remove stopwords
    stopwords = StopwordsFilter::Filter.new(:en)
    words = text.downcase.gsub(/[^\w\s]/, '').split
    filtered_words = words.reject { |word| stopwords.stopword?(word) }
    
    # Count word frequencies
    word_counts = Hash.new(0)
    filtered_words.each { |word| word_counts[word] += 1 }
    
    # Return top keywords
    word_counts.sort_by { |_, count| -count }.take(count).map(&:first)
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