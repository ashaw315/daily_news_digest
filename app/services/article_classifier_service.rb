require 'openai'

class ArticleClassifierService
  CATEGORIES = %w[Technology Business Politics Science Culture Sports Health World].freeze
  DEFAULT_CATEGORY = "World"

  def initialize
    @client = OpenAI::Client.new(
      access_token: ENV['OPENAI_API_KEY'],
      request_timeout: 15
    )
  end

  def classify(title:, summary:)
    return DEFAULT_CATEGORY if title.blank? && summary.blank?

    response = @client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [
          {
            role: "system",
            content: "You are a news article classifier. Given an article title and summary, return exactly one category from this list: #{CATEGORIES.join(', ')}. Return only the category name, nothing else."
          },
          {
            role: "user",
            content: "Title: #{title}\nSummary: #{summary}"
          }
        ],
        temperature: 0.1,
        max_tokens: 10
      }
    )

    raw = response.dig("choices", 0, "message", "content").to_s.strip
    category = CATEGORIES.find { |c| c.casecmp?(raw) }

    if category
      Rails.logger.info("[ArticleClassifier] '#{title.to_s.truncate(60)}' → #{category}")
      category
    else
      Rails.logger.warn("[ArticleClassifier] Unrecognized response '#{raw}' for '#{title.to_s.truncate(60)}', defaulting to #{DEFAULT_CATEGORY}")
      DEFAULT_CATEGORY
    end
  rescue => e
    Rails.logger.error("[ArticleClassifier] Failed for '#{title.to_s.truncate(60)}': #{e.message}")
    DEFAULT_CATEGORY
  end
end
