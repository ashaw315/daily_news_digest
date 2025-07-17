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
    @request_count = 0
    @rate_limited_until = nil
    configure_client
  end

  def generate_summary(content, word_count = 100)
    return nil if content.blank?
    
    puts "\n=== AI Summary Generation ==="
    display_rate_limit_status
    
    if rate_limited?
      puts "Currently rate limited. Please wait."
      return fallback_summary(content, word_count)
    end

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
      
      increment_request_count
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
      handle_api_error(e)
      if e.message.include?('429')
        mark_rate_limited
        sleep(RATE_LIMIT_DELAY)
        retry if (retries += 1) < MAX_RETRIES
      end
    rescue => e
      handle_api_error(e)
      retry if (retries += 1) < MAX_RETRIES
    end

    puts "All retries failed, using fallback"
    fallback_summary(content, word_count)
  end

  def check_rate_limit_status
    {
      requests_today: @request_count,
      rate_limited: rate_limited?,
      rate_limit_expires: @rate_limited_until,
      requests_remaining: 200 - @request_count # Assuming 200/day limit
    }
  end

  private

  def configure_client
    if ENV['OPENAI_API_KEY'].blank?
      error_msg = "OpenAI API key not configured!"
      puts "ERROR: #{error_msg}"
      @errors << error_msg
      raise error_msg
    end
    
    @client = OpenAI::Client.new(
      access_token: ENV['OPENAI_API_KEY'],
      request_timeout: 30
    )
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

  def display_rate_limit_status
    status = check_rate_limit_status
    puts "\nRate Limit Status:"
    puts "- Requests made today: #{status[:requests_today]}"
    puts "- Requests remaining: #{status[:requests_remaining]}"
    puts "- Rate limited: #{status[:rate_limited]}"
    if status[:rate_limited]
      puts "- Rate limit expires: #{status[:rate_limit_expires]}"
    end
    puts
  end

  def increment_request_count
    @request_count += 1
  end

  def mark_rate_limited
    @rate_limited_until = Time.now + 24.hours
  end

  def rate_limited?
    return false if @rate_limited_until.nil?
    Time.now < @rate_limited_until
  end

  def handle_api_error(error)
    case error.message
    when /429/
      rate_limit_info = <<~INFO
        \nRATE LIMIT HIT: You've reached OpenAI's rate limit.
        Current Status:
        - Requests today: #{@request_count}
        - Rate limited until: #{@rate_limited_until}
        
        Limits:
        - Per minute: 3 requests
        - Per day: ~200 requests
        
        Try again:
        - After 20 seconds for per-minute limits
        - Tomorrow for daily limits
      INFO
      puts rate_limit_info
      @errors << "Rate limit exceeded"
    when /401/
      puts "AUTHENTICATION ERROR: Invalid API key or token expired"
      @errors << "Authentication failed"
    when /503/
      puts "SERVICE ERROR: OpenAI API is temporarily unavailable"
      @errors << "Service unavailable"
    else
      puts "AI summarization error: #{error.message}"
      puts "Error type: #{error.class}"
      puts "Full error details: #{error.inspect}"
      @errors << "General error: #{error.message}"
    end
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