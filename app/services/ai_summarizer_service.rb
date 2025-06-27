require 'openai'

class AiSummarizerService
  attr_reader :errors

  MIN_CONTENT_LENGTH = 400  # Minimum chars needed for summarization
  MAX_RETRIES = 3          # Maximum retries for API calls
  RETRY_DELAY = 2          # Seconds to wait between retries
  RATE_LIMIT_DELAY = 3     # Seconds to wait after rate limit hit

  def initialize
    @errors = []
    @last_api_call = Time.now - 60  # Initialize to avoid immediate rate limiting
    configure_client
  end

  def generate_summary(content, word_count = 100)
    return nil if content.blank?
    
    puts "\n=== AI Summary Generation ==="
    puts "Content length: #{content.length} chars"
    
    # Don't summarize if content is too short
    if content.length < MIN_CONTENT_LENGTH
      puts "Content too short (< #{MIN_CONTENT_LENGTH} chars), using as is"
      return clean_content(content)
    end

    prompt = create_prompt(content, word_count)
    
    retries = 0
    begin
      respect_rate_limit
      puts "Sending request to OpenAI (attempt #{retries + 1}/#{MAX_RETRIES})..."
      
      response = @client.chat(
        parameters: {
          model: "gpt-3.5-turbo",
          messages: [{ role: "user", content: prompt }],
          temperature: 0.5,
          max_tokens: 250,
          presence_penalty: 0.2
        }
      )
      
      @last_api_call = Time.now
      summary = response.dig("choices", 0, "message", "content")
      
      if summary.present?
        puts "Successfully generated summary (#{summary.length} chars)"
        return clean_content(summary)
      else
        puts "No summary received from API"
        raise "Empty response from OpenAI"
      end

    rescue OpenAI::Error => e
      if e.message.include?('429') # Rate limit error
        puts "Rate limit hit, waiting #{RATE_LIMIT_DELAY} seconds..."
        sleep(RATE_LIMIT_DELAY)
        retry if (retries += 1) < MAX_RETRIES
      else
        handle_api_error(e)
      end
    rescue => e
      handle_api_error(e)
      retry if (retries += 1) < MAX_RETRIES
    end

    puts "All retries failed, using fallback"
    fallback_summary(content, word_count)
  end

  private

  def configure_client
    if ENV['OPENAI_API_KEY'].blank?
      error_msg = "OpenAI API key not configured!"
      puts "ERROR: #{error_msg}"
      @errors << error_msg
      raise error_msg
    end
    
    @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
    puts "OpenAI client configured successfully"
  rescue => e
    error_msg = "Failed to configure OpenAI client: #{e.message}"
    puts "ERROR: #{error_msg}"
    @errors << error_msg
    raise
  end

  def create_prompt(content, word_count)
    <<~PROMPT
      Summarize this article in about #{word_count} words.
      Maintain a professional journalistic style.
      Focus on key facts and important details.
      Ensure the summary is complete and coherent.
      Use clear, engaging language.
      End with a complete sentence.

      Article:
      #{content}
    PROMPT
  end

  def respect_rate_limit
    elapsed = Time.now - @last_api_call
    if elapsed < 1.0  # Ensure at least 1 second between calls
      sleep_time = 1.0 - elapsed
      puts "Rate limiting: waiting #{sleep_time.round(2)} seconds..."
      sleep(sleep_time)
    end
  end

  def handle_api_error(error)
    error_msg = "AI summarization error: #{error.message}"
    puts "ERROR: #{error_msg}"
    @errors << error_msg
  end

  def fallback_summary(content, word_count)
    puts "Generating fallback summary..."
    
    # Split into sentences
    sentences = content.split(/(?<=[.!?])\s+/)
    
    summary = ""
    word_count_so_far = 0
    
    sentences.each do |sentence|
      words_in_sentence = sentence.split(/\s+/).length
      
      # Stop if adding this sentence would exceed word count
      break if word_count_so_far + words_in_sentence > word_count
      
      summary += sentence + " "
      word_count_so_far += words_in_sentence
    end
    
    summary = clean_content(summary)
    puts "Generated fallback summary (#{summary.length} chars)"
    summary
  end

  def clean_content(text)
    return "" if text.blank?
    
    text
      .gsub(/\s+/, ' ')        # Normalize whitespace
      .gsub(/\A[^a-zA-Z]+/, '') # Remove leading non-letter chars
      .strip
      .tap { |s| s << '.' unless s.end_with?('.', '!', '?') } # Ensure it ends with punctuation
  end
end