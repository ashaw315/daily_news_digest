# app/services/enhanced_news_fetcher.rb

require 'feedjira'
require 'open-uri'
require 'net/http'
require 'json'
require 'nokogiri'

class EnhancedNewsFetcher
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

  def initialize(options = {})
    @options = options
    @sources = options[:sources] || []
    @max_articles = options[:max_articles] || 50
    @summarizer = AiSummarizerService.new
  end

  def fetch_articles
    articles = []
    @sources.each do |source|
      begin
        new_articles = fetch_from_rss_and_summarize(source)
        articles.concat(new_articles)
        break if articles.length >= @max_articles
      rescue => e
        Rails.logger.error("Error fetching from #{source.name}: #{e.message}")
        source.update(
          last_fetched_at: Time.current,
          last_fetch_status: 'error',
          last_fetch_article_count: 0
        )
      end
    end
    articles
  end

  private

  def fetch_full_content_with_fivefilters(url)
    api_url = "https://ftr.fivefilters.net/makefulltextfeed.php?url=#{URI.encode_www_form_component(url)}&format=json"
    uri = URI(api_url)
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = USER_AGENT

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    data = JSON.parse(response.body)
    if data["rss"] && data["rss"]["channel"] && data["rss"]["channel"]["item"] && data["rss"]["channel"]["item"][0]
      html = data["rss"]["channel"]["item"][0]["description"]
      Nokogiri::HTML(html).text
    else
      ""
    end
  rescue => e
    Rails.logger.warn("FiveFilters failed for #{url}: #{e.message}")
    ""
  end

  def fetch_from_rss_and_summarize(source)
    # Use open-uri with custom User-Agent for RSS fetch
    xml = URI.open(source.url, "User-Agent" => USER_AGENT).read
    feed = Feedjira.parse(xml)
    entries = feed.entries.take(@max_articles)

    articles = entries.map do |entry|
      url = entry.url || entry.link
      full_content = fetch_full_content_with_fivefilters(url)
      full_content = entry.summary || entry.content || "" if full_content.blank?

      summary = @summarizer.summarize(full_content, 250)

      {
        title: entry.title,
        description: summary,
        url: url,
        published_at: entry.published || Time.now,
        topic: nil, # You can add categorization here if needed
        source: source.name
      }
    end

    # Update NewsSource fetch stats
    source.update(
      last_fetched_at: Time.current,
      last_fetch_status: 'success',
      last_fetch_article_count: articles.size
    )

    articles
  end
end