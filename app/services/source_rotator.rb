class SourceRotator
  def initialize
    @source_stats = load_source_stats
  end
  
  def prioritized_sources
    # Sort sources by score (higher is better)
    @source_stats.sort_by { |_, stats| -calculate_score(stats) }.map { |name, _| name }
  end
  
  def update_source_stats(source_name, success, response_time = nil)
    stats = @source_stats[source_name] ||= default_stats
    
    # Update success rate
    stats[:total_requests] += 1
    stats[:successful_requests] += 1 if success
    
    # Update response time if provided
    if response_time && response_time > 0
      stats[:total_response_time] += response_time
      stats[:response_time_count] += 1
    end
    
    # Update last used timestamp
    stats[:last_used_at] = Time.now
    
    # Save updated stats
    save_source_stats
  end
  
  private
  
  def load_source_stats
    Rails.cache.fetch('news_source_stats', expires_in: 1.day) do
      # Default empty hash if no stats exist yet
      {}
    end
  end
  
  def save_source_stats
    Rails.cache.write('news_source_stats', @source_stats, expires_in: 1.day)
  end
  
  def default_stats
    {
      total_requests: 0,
      successful_requests: 0,
      total_response_time: 0,
      response_time_count: 0,
      last_used_at: nil
    }
  end
  
  def calculate_score(stats)
    # Avoid division by zero
    return 0 if stats[:total_requests] == 0
    
    # Calculate success rate (0-1)
    success_rate = stats[:successful_requests].to_f / stats[:total_requests]
    
    # Calculate average response time (in seconds)
    avg_response_time = stats[:response_time_count] > 0 ? 
                        stats[:total_response_time].to_f / stats[:response_time_count] : 
                        10 # Default to 10 seconds if no data
    
    # Calculate time since last use (in hours, max 24)
    hours_since_last_use = stats[:last_used_at] ? 
                          [(Time.now - stats[:last_used_at]) / 3600, 24].min : 
                          24 # Default to 24 hours if never used
    
    # Calculate score: success rate is most important, then response time, then time since last use
    # Higher score is better
    (success_rate * 10) + (1 / [avg_response_time, 1].max) + (hours_since_last_use / 24)
  end
end 