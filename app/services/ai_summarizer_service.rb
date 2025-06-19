class AiSummarizerService
  attr_reader :errors

  def initialize
    @errors = []
  end

  def summarize(content, word_count = 250)
    return content if content.blank? || content.split(/\s+/).length <= word_count

    begin
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
    importance = {}
    words_by_frequency = count_word_frequency(content)

    sentences.each_with_index do |sentence, index|
      position_score = 1.0 / (index + 1)
      word_score = sentence.split(/\s+/).sum { |word| words_by_frequency[word.downcase.gsub(/[^\w]/, '')] || 0 }
      importance[sentence] = (position_score * 0.3) + (word_score * 0.7)
    end

    sorted_sentences = sentences.sort_by { |s| -importance[s] }
    current_word_count = 0
    summary_sentences = []

    sorted_sentences.each do |sentence|
      sentence_words = sentence.split(/\s+/).size
      break if current_word_count + sentence_words > word_count
      summary_sentences << sentence
      current_word_count += sentence_words
    end

    summary_sentences = summary_sentences.sort_by { |s| sentences.index(s) }
    summary_sentences.join(' ')
  end

  def count_word_frequency(text)
    words = text.downcase.gsub(/[^\w\s]/, '').split(/\s+/)
    frequencies = Hash.new(0)
    words.each { |word| frequencies[word] += 1 unless word.length < 3 }
    max_frequency = frequencies.values.max.to_f
    frequencies.transform_values { |v| v / max_frequency }
  end

  def fallback_summary(content, word_count)
    words = content.split(/\s+/)
    summary = words.take(word_count).join(' ')
    summary += '...' if words.length > word_count
    summary
  end
end