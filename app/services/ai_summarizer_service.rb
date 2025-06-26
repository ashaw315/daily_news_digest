require 'openai'

class AiSummarizerService
  attr_reader :errors

  def initialize
    @errors = []
    @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  end

  def summarize(content, word_count = 250)
    return content if content.blank? || content.split(/\s+/).length <= word_count

    prompt = <<~PROMPT
      Summarize the following article in about #{word_count} words, focusing on the main points and key details:

      #{content}
    PROMPT

    begin
      response = @client.chat(
        parameters: {
          model: "gpt-3.5-turbo",
          messages: [{ role: "user", content: prompt }],
          temperature: 0.5,
          max_tokens: 800
        }
      )
      summary = response.dig("choices", 0, "message", "content")
      summary.present? ? summary.strip : fallback_summary(content, word_count)
    rescue => e
      @errors << "Summarization failed: #{e.message}"
      fallback_summary(content, word_count)
    end
  end

  private

  def fallback_summary(content, word_count)
    words = content.split(/\s+/)
    summary = words.take(word_count).join(' ')
    summary += '...' if words.length > word_count
    summary
  end
end