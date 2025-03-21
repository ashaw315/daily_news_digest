module MailerHelper
  def topic_icon(topic)
    case topic.to_s.downcase
    when 'technology'
      '💻'
    when 'science'
      '🔬'
    when 'health'
      '🏥'
    when 'sports'
      '🏆'
    when 'business'
      '💼'
    when 'entertainment'
      '🎬'
    when 'politics'
      '🏛️'
    when 'world'
      '🌎'
    else
      '��'
    end
  end
end 