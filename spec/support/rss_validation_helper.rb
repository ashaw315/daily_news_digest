# spec/support/rss_validation_helper.rb
RSpec.shared_context "rss validation stubs" do
    before do
      # Stub the Hacker News RSS feed
      stub_request(:get, "https://hnrss.org/frontpage")
        .with(headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Host' => 'hnrss.org',
          'User-Agent' => 'Ruby'
        })
        .to_return({
          status: 200,
          body: <<~XML,
            <?xml version="1.0" encoding="UTF-8"?>
            <rss version="2.0">
              <channel>
                <title>Hacker News</title>
                <link>https://news.ycombinator.com/</link>
                <description>Hacker News RSS</description>
                <item>
                  <title>Test Article</title>
                  <link>https://example.com/article</link>
                  <description>Test Description</description>
                  <pubDate>#{Time.now.rfc2822}</pubDate>
                </item>
              </channel>
            </rss>
          XML
          headers: {'Content-Type' => 'application/rss+xml'}
        })
  
      # Stub any other RSS feeds
      stub_request(:get, /.*/)
        .to_return({
          status: 200,
          body: <<~XML,
            <?xml version="1.0" encoding="UTF-8"?>
            <rss version="2.0">
              <channel>
                <title>Test Feed</title>
                <link>http://example.com</link>
                <description>Test RSS Feed</description>
                <item>
                  <title>Test Article</title>
                  <link>http://example.com/article</link>
                  <description>Test Description</description>
                  <pubDate>#{Time.now.rfc2822}</pubDate>
                </item>
              </channel>
            </rss>
          XML
          headers: {'Content-Type' => 'application/rss+xml'}
        })
    end
  end