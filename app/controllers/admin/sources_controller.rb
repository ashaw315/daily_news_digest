class Admin::SourcesController < Admin::BaseController
  before_action :set_source, only: [:show, :edit, :update, :destroy]
  
  def index
    @sources = Source.all
  end
  
  def show
  end
  
  def new
    @source = Source.new
  end
  
  def create
    @source = Source.new(source_params)
    
    if @source.save
      redirect_to admin_sources_path, notice: 'Source was successfully created.'
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @source.update(source_params)
      redirect_to admin_sources_path, notice: 'Source was successfully updated.'
    else
      render :edit
    end
  end
  
  def destroy
    @source.destroy
    redirect_to admin_sources_path, notice: 'Source was successfully destroyed.'
  end
  
  private
  
  def set_source
    @source = Source.find(params[:id])
  end
  
  def source_params
    params.require(:source).permit(:name, :url, :source_type, :active, selectors: {})
  end
end 