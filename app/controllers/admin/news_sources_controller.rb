class Admin::NewsSourcesController < Admin::BaseController
  before_action :set_source, only: [:show, :edit, :update, :destroy, :validate, :preview]

  def index
    @sources = NewsSource.all
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
    # Create a fetcher with just this source, in detailed preview mode
    fetcher = NewsFetcher.new(
      sources: [
        {
          id: @source.id,
          name: @source.name,
          url: @source.url,
          type: :rss,  # Always use RSS format
          settings: @source.settings
        }
      ],
      detailed_preview: true,
      preview_article_count: 3  # Limit to 3 articles for preview
    )
    
    # Fetch articles
    @articles = fetcher.fetch_articles || []
    
    # Log the results
    Rails.logger.info("Preview fetched #{@articles.size} articles")
    @articles.each_with_index do |article, index|
      Rails.logger.info("Article #{index+1}: #{article[:title]}")
      Rails.logger.info("  URL: #{article[:url]}")
      Rails.logger.info("  Content length: #{article[:content]&.length || 0} characters")
      Rails.logger.info("  Description length: #{article[:description]&.length || 0} characters")
      Rails.logger.info("  Description: #{article[:description]}")
    end
    
    respond_to do |format|
      format.html
      format.json { render json: @articles }
    end
  end

  private

  def set_source
    @source = NewsSource.find(params[:id])
  end

  def source_params
    permitted = params.require(:news_source).permit(:name, :url, :active, :format, :is_validated)
    
    # Set an empty hash for settings since we don't need complex settings for RSS
    permitted[:settings] = {}
    
    permitted
  end
end