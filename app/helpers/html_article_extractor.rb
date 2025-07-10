class HtmlArticleExtractor
    def initialize(html_content)
      @doc = Nokogiri::HTML(html_content)
    end
  
    def extract_articles
      articles = []
      
      article_elements = find_article_elements
      
      article_elements.each do |element|
        article = extract_article(element)
        articles << article if article_valid?(article)
      end
      
      articles
    end
  
    def has_valid_articles?
      article_elements = find_article_elements
      return false if article_elements.empty?
      
      # Check if at least one article has required fields
      article_elements.any? do |element|
        article = extract_article(element)
        article_valid?(article)
      end
    end
  
    private
  
    def find_article_elements
      @doc.css('article') || 
      @doc.css('[data-testid*="article"]') ||
      @doc.css('.article-item') ||
      @doc.css('h2 a, h3 a') ||
      @doc.css('a[href*="/article/"]') || # Common article URL pattern
      []
    end
  
    def extract_article(element)
      {
        title: extract_title(element),
        url: normalize_url(extract_link(element)),
        description: extract_description(element),
        published_at: extract_date(element)
      }
    end
  
    def article_valid?(article)
      article[:title].present? && article[:url].present?
    end
  
    def extract_title(element)
      element.css('h1, h2, h3, h4').first&.text&.strip ||
      element.text.strip.presence ||
      element.attr('title')
    end
  
    def extract_link(element)
      if element.name == 'a'
        element.attr('href')
      else
        element.css('a').first&.attr('href')
      end
    end
  
    def extract_description(element)
      element.css('p, .summary, .excerpt').first&.text&.strip
    end
  
    def extract_date(element)
      date_element = element.css('time, .date, [datetime]').first
      return nil unless date_element
      
      date_element.attr('datetime') || date_element.text
    end
  
    def normalize_url(url)
      return nil if url.blank?
      return url if url.start_with?('http')
      
      # Get base URL from source if available
      base_url = @doc.at_css('base')&.attr('href')
      return "#{base_url.chomp('/')}#{url}" if base_url.present?
      
      # Fallback to constructing from URL
      uri = URI.parse(url)
      return url if uri.host.present?
      
      "https://#{uri.host || 'example.com'}#{url}"
    end
  end