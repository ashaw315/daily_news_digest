class Admin::NewsSourcesController < Admin::BaseController
  before_action :set_source, only: [:show, :edit, :update, :destroy, :validate, :preview]

  def index
    # Add pagination to prevent memory issues with kaminari
    @sources = NewsSource.includes(:topic).page(params[:page]).per(20)
  end

  def show
  end

  def new
    @source = NewsSource.new
    @source.format = 'rss' # Default to RSS format
  end

  def edit
  end

  def create
    @source = NewsSource.new(source_params.except(:is_validated))
    
    # Always set format to RSS
    @source.format = 'rss'
    
    # Check if validation was performed
    if params[:news_source][:is_validated] != "true"
      flash.now[:alert] = "Please validate the RSS feed before creating"
      return render :new, status: :unprocessable_entity
    end
    
    # Validate again on the server side for security
    validator = SourceValidatorService.new(@source)
    if validator.validate
      if @source.save
        redirect_to admin_news_source_path(@source), notice: 'News source was successfully created.'
      else
        render :new, status: :unprocessable_entity
      end
    else
      flash.now[:alert] = "Invalid RSS feed: #{validator.errors.join(', ')}"
      render :new, status: :unprocessable_entity
    end
  end
  
  def update
    # Store original URL for comparison
    original_url = @source.url
    
    # Check if URL has changed and needs revalidation
    if original_url != source_params[:url] && params[:news_source][:is_validated] != "true"
      flash.now[:alert] = "You've changed the URL. Please validate the RSS feed before updating."
      @source.assign_attributes(source_params.except(:is_validated))
      return render :edit, status: :unprocessable_entity
    end
    
    # If URL has changed, revalidate on server side
    if original_url != source_params[:url]
      temp_source = @source.dup
      temp_source.assign_attributes(source_params.except(:is_validated))
      temp_source.format = 'rss'
      
      validator = SourceValidatorService.new(temp_source)
      unless validator.validate
        flash.now[:alert] = "Invalid RSS feed: #{validator.errors.join(', ')}"
        @source.assign_attributes(source_params.except(:is_validated))
        return render :edit, status: :unprocessable_entity
      end
    end
    
    # Always ensure format is RSS
    updated_params = source_params.except(:is_validated).merge(format: 'rss')
    
    if @source.update(updated_params)
      redirect_to admin_news_source_path(@source), notice: 'News source was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @source.in_use?
      redirect_to admin_news_sources_path, alert: 'Cannot delete a news source that is in use by users.'
    else
      @source.destroy
      redirect_to admin_news_sources_path, notice: 'News source was successfully destroyed.'
    end
  end

  def validate_new
    # Extract is_validated from params but don't try to assign it to the model
    @source = NewsSource.new(source_params.except(:is_validated))
    @source.format = 'rss' # Ensure format is RSS
    result = @source.validate_source
    
    # Always respond with JSON
    render json: {
      valid: result === true,
      message: result === true ? "RSS feed validated successfully" : nil,
      errors: result === true ? [] : (result.is_a?(Array) ? result : [result.to_s])
    }
  end
  
  def validate
    # Same here - don't try to assign is_validated to the model
    if params[:news_source].present?
      @source.assign_attributes(source_params.except(:is_validated))
    end
    
    @source.format = 'rss' # Ensure format is RSS
    result = @source.validate_source
    
    # Always respond with JSON
    render json: {
      valid: result === true,
      message: result === true ? "RSS feed validated successfully" : nil,
      errors: result === true ? [] : (result.is_a?(Array) ? result : [result.to_s])
    }
  end

  def preview
    # Performance monitoring - track start time and memory
    start_time = Time.current
    initial_memory = get_memory_usage_mb
    Rails.logger.info("PREVIEW START - Memory: #{initial_memory}MB")
    
    begin
      # Force garbage collection before starting
      GC.start
      
      # Use enhanced fetcher WITHOUT summarization to avoid double processing
      fetcher = EnhancedNewsFetcher.new(
        sources: [@source],
        max_articles: 3,
        summarize: false  # CRITICAL: Don't summarize during fetch
      )
      
      # Fetch articles without AI processing
      fetch_start_time = Time.current
      raw_articles = fetcher.fetch_articles || []
      fetch_duration = ((Time.current - fetch_start_time) * 1000).round(2)
      
      Rails.logger.info("PREVIEW: Fetched #{raw_articles.size} articles in #{fetch_duration}ms")
      
      # Force garbage collection after fetch
      GC.start
      mid_memory = get_memory_usage_mb
      Rails.logger.info("PREVIEW AFTER FETCH - Memory: #{mid_memory}MB")
      
      # Process articles in parallel with AI summaries (ONLY here)
      processing_start_time = Time.current
      processor = ParallelArticleProcessor.new
      @articles = processor.process_articles(raw_articles)
      processing_duration = ((Time.current - processing_start_time) * 1000).round(2)
      
      # Get performance statistics
      performance_stats = processor.performance_stats
      total_duration = ((Time.current - start_time) * 1000).round(2)
      final_memory = get_memory_usage_mb
      memory_used = final_memory - initial_memory
      
      # Log detailed performance results
      Rails.logger.info("PREVIEW COMPLETE:")
      Rails.logger.info("  Total time: #{total_duration}ms (#{(total_duration/1000).round(1)}s)")
      Rails.logger.info("  Fetch time: #{fetch_duration}ms")
      Rails.logger.info("  Processing time: #{processing_duration}ms")
      Rails.logger.info("  Articles: #{@articles.size}/3")
      Rails.logger.info("  Success rate: #{performance_stats[:success_rate]}%")
      Rails.logger.info("  Memory: #{initial_memory}MB → #{final_memory}MB (#{memory_used >= 0 ? '+' : ''}#{memory_used}MB)")
      
      # Log individual article results
      @articles.each_with_index do |article, index|
        processing_time = article[:processing_time_ms] || 0
        Rails.logger.info("  Article #{index+1}: #{article[:title]} (#{processing_time}ms)")
        Rails.logger.info("    Summary: #{article[:summary]&.length || 0} chars")
      end
      
      # Handle any processing errors
      if processor.errors.any?
        Rails.logger.warn("PREVIEW: Processing errors: #{processor.errors.join(', ')}")
        flash.now[:alert] = "Some articles had processing issues"
      end
      
      # Create user-friendly performance message
      if total_duration < 8000  # Less than 8 seconds (target)
        performance_message = "⚡ Fast preview: #{(total_duration/1000).round(1)}s"
      elsif total_duration < 15000  # Less than 15 seconds
        performance_message = "✅ Preview: #{(total_duration/1000).round(1)}s"
      else
        performance_message = "⏱️ Preview: #{(total_duration/1000).round(1)}s"
      end
      
      flash.now[:notice] = "#{performance_message} | #{@articles.size} articles | #{final_memory}MB memory"
      
      respond_to do |format|
        format.html
        format.json { 
          render json: {
            articles: @articles,
            performance: {
              total_duration_ms: total_duration,
              fetch_duration_ms: fetch_duration,
              processing_duration_ms: processing_duration,
              memory_initial_mb: initial_memory,
              memory_final_mb: final_memory,
              memory_used_mb: memory_used,
              success_rate: performance_stats[:success_rate],
              parallel_efficiency: performance_stats[:parallel_efficiency]
            },
            errors: processor.errors
          }
        }
      end
      
    rescue => e
      # Error handling with performance context
      error_time = Time.current
      error_duration = ((error_time - start_time) * 1000).round(2)
      error_memory = get_memory_usage_mb
      
      Rails.logger.error("PREVIEW ERROR after #{error_duration}ms at #{error_memory}MB:")
      Rails.logger.error("  Error: #{e.message}")
      Rails.logger.error("  Backtrace: #{e.backtrace.first(3).join(' | ')}")
      
      flash.now[:alert] = "Preview failed after #{(error_duration/1000).round(1)}s: #{e.message}"
      @articles = []
      
      respond_to do |format|
        format.html
        format.json { 
          render json: { 
            error: e.message,
            duration_ms: error_duration,
            memory_mb: error_memory,
            articles: []
          }, 
          status: :internal_server_error 
        }
      end
      
    ensure
      # Final cleanup and performance logging
      begin
        # Force garbage collection
        GC.start
        
        cleanup_memory = get_memory_usage_mb
        final_total_duration = ((Time.current - start_time) * 1000).round(2)
        
        Rails.logger.info("PREVIEW CLEANUP:")
        Rails.logger.info("  Final memory: #{cleanup_memory}MB")
        Rails.logger.info("  Total request time: #{final_total_duration}ms")
        
      rescue => cleanup_error
        Rails.logger.error("PREVIEW: Cleanup error: #{cleanup_error.message}")
      end
    end
  end

  private

  def set_source
    @source = NewsSource.find(params[:id])
  end

  def source_params
    permitted = params.require(:news_source).permit(:name, :url, :active, :format, :is_validated, :topic_id)
    
    # Set an empty hash for settings since we don't need complex settings for RSS
    permitted[:settings] = {}
    
    permitted
  end
  
  # Memory monitoring helper method
  def get_memory_usage_mb
    rss_kb = `ps -o rss= -p #{Process.pid}`.to_i
    (rss_kb / 1024.0).round(2)
  rescue => e
    Rails.logger.error("Error getting memory usage: #{e.message}")
    0.0
  end
end