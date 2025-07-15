class MemoryMonitor
  # Memory safety constants for 512MB environment
  MEMORY_WARNING_THRESHOLD = 350   # MB - Log warning
  MEMORY_DANGER_THRESHOLD = 400    # MB - Force GC
  MEMORY_CRITICAL_THRESHOLD = 450  # MB - Stop processing
  
  class << self
    # Get current memory usage in MB
    def current_usage_mb
      rss_kb = `ps -o rss= -p #{Process.pid}`.to_i
      (rss_kb / 1024.0).round(2)
    rescue => e
      Rails.logger.error("[MemoryMonitor] Error getting memory usage: #{e.message}")
      0.0
    end
    
    # Check if memory usage is safe to continue processing
    def safe_to_continue?
      usage = current_usage_mb
      
      case usage
      when 0..MEMORY_WARNING_THRESHOLD
        true
      when MEMORY_WARNING_THRESHOLD..MEMORY_DANGER_THRESHOLD
        Rails.logger.warn("[MemoryMonitor] Memory usage high: #{usage}MB")
        true
      when MEMORY_DANGER_THRESHOLD..MEMORY_CRITICAL_THRESHOLD
        Rails.logger.error("[MemoryMonitor] Memory usage dangerous: #{usage}MB - forcing GC")
        GC.start
        after_gc = current_usage_mb
        Rails.logger.info("[MemoryMonitor] After GC: #{usage}MB → #{after_gc}MB")
        after_gc < MEMORY_CRITICAL_THRESHOLD
      else
        Rails.logger.error("[MemoryMonitor] Memory usage critical: #{usage}MB - stopping processing")
        false
      end
    end
    
    # Force garbage collection and return memory change
    def force_gc_and_report(context = "Manual GC")
      before = current_usage_mb
      GC.start
      after = current_usage_mb
      saved = before - after
      
      Rails.logger.info("[MemoryMonitor] #{context}: #{before}MB → #{after}MB (saved #{saved.round(2)}MB)")
      
      {
        before: before,
        after: after,
        saved: saved
      }
    end
    
    # Monitor memory usage during a block execution
    def monitor(operation_name = "Operation")
      start_time = Time.current
      start_memory = current_usage_mb
      
      Rails.logger.info("[MemoryMonitor] Starting #{operation_name} - Memory: #{start_memory}MB")
      
      unless safe_to_continue?
        raise MemoryLimitExceededException, "Memory too high to start #{operation_name}: #{start_memory}MB"
      end
      
      begin
        result = yield
        
        end_memory = current_usage_mb
        duration = (Time.current - start_time).round(2)
        memory_change = end_memory - start_memory
        
        Rails.logger.info("[MemoryMonitor] Completed #{operation_name} in #{duration}s")
        Rails.logger.info("[MemoryMonitor] Memory: #{start_memory}MB → #{end_memory}MB (#{memory_change >= 0 ? '+' : ''}#{memory_change.round(2)}MB)")
        
        # Log warning if memory increased significantly
        if memory_change > 50
          Rails.logger.warn("[MemoryMonitor] Large memory increase during #{operation_name}: +#{memory_change.round(2)}MB")
        end
        
        result
      rescue => e
        error_memory = current_usage_mb
        Rails.logger.error("[MemoryMonitor] Error during #{operation_name} at #{error_memory}MB: #{e.message}")
        raise e
      end
    end
    
    # Get memory statistics for reporting
    def stats
      usage = current_usage_mb
      limit = 512
      percentage = (usage / limit * 100).round(1)
      
      {
        current_mb: usage,
        limit_mb: limit,
        usage_percentage: percentage,
        available_mb: (limit - usage).round(2),
        status: memory_status(usage),
        safe_to_continue: safe_to_continue?
      }
    end
    
    # Get memory status as string
    def memory_status(usage = nil)
      usage ||= current_usage_mb
      
      case usage
      when 0..MEMORY_WARNING_THRESHOLD
        "SAFE"
      when MEMORY_WARNING_THRESHOLD..MEMORY_DANGER_THRESHOLD
        "WARNING"
      when MEMORY_DANGER_THRESHOLD..MEMORY_CRITICAL_THRESHOLD
        "DANGER"
      else
        "CRITICAL"
      end
    end
    
    # Log comprehensive memory report
    def log_report(context = "Memory Report")
      statistics = stats
      
      Rails.logger.info("[MemoryMonitor] #{context}:")
      Rails.logger.info("  Current Usage: #{statistics[:current_mb]}MB / #{statistics[:limit_mb]}MB (#{statistics[:usage_percentage]}%)")
      Rails.logger.info("  Available: #{statistics[:available_mb]}MB")
      Rails.logger.info("  Status: #{statistics[:status]}")
      Rails.logger.info("  Safe to Continue: #{statistics[:safe_to_continue]}")
      
      statistics
    end
    
    # Check if we should pause processing to let memory settle
    def should_pause_processing?
      current_usage_mb > MEMORY_DANGER_THRESHOLD
    end
    
    # Pause processing if memory is high
    def pause_if_needed(pause_duration = 2)
      if should_pause_processing?
        usage = current_usage_mb
        Rails.logger.warn("[MemoryMonitor] Pausing #{pause_duration}s due to high memory: #{usage}MB")
        sleep(pause_duration)
        force_gc_and_report("Post-pause GC")
      end
    end
  end
  
  # Custom exception for memory limit exceeded
  class MemoryLimitExceededException < StandardError; end
end