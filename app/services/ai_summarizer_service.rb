class AiSummarizerService
  attr_reader :errors

  def initialize
    @errors = []
  end

  def summarize(content, word_count = 100)
    return content if content.blank? || content.split(/\s+/).length <= word_count

    begin
      # Create a proper summary instead of just truncating
      create_proper_summary(content, word_count)
    rescue => e
      @errors << "Summarization failed: #{e.message}"
      fallback_summary(content, word_count)
    end
  end

  private

  def create_proper_summary(content, word_count)
    # Split content into sentences
    sentences = content.split(/(?<=[.!?])\s+/)
    
    # Calculate importance of each sentence (simple algorithm)
    importance = {}
    words_by_frequency = count_word_frequency(content)
    
    sentences.each_with_index do |sentence, index|
      # Score based on position (first sentences are usually more important)
      position_score = 1.0 / (index + 1)
      
      # Score based on words in the sentence
      word_score = 0
      sentence.split(/\s+/).each do |word|
        word = word.downcase.gsub(/[^\w]/, '')
        word_score += words_by_frequency[word] || 0
      end
      
      # Combine scores
      importance[sentence] = (position_score * 0.3) + (word_score * 0.7)
    end
    
    # Sort sentences by importance
    sorted_sentences = sentences.sort_by { |s| -importance[s] }
    
    # Take the most important sentences until we reach the word limit
    current_word_count = 0
    summary_sentences = []
    
    sorted_sentences.each do |sentence|
      sentence_words = sentence.split(/\s+/).size
      if current_word_count + sentence_words <= word_count
        summary_sentences << sentence
        current_word_count += sentence_words
      else
        break
      end
    end
    
    # Sort the selected sentences to maintain the original order
    summary_sentences = summary_sentences.sort_by { |s| sentences.index(s) }
    
    summary_sentences.join(' ')
  end

  def count_word_frequency(text)
    # Count word frequencies
    words = text.downcase.gsub(/[^\w\s]/, '').split(/\s+/)
    frequencies = Hash.new(0)
    words.each { |word| frequencies[word] += 1 unless word.length < 3 }
    
    # Normalize by maximum frequency
    max_frequency = frequencies.values.max.to_f
    frequencies.transform_values { |v| v / max_frequency }
  end

  def fallback_summary(content, word_count)
    # Simple fallback: take the first N words
    words = content.split(/\s+/)
    summary = words.take(word_count).join(' ')
    summary += '...' if words.length > word_count
    summary
  end
end