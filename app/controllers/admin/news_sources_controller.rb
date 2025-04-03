class Admin::NewsSourcesController < Admin::BaseController
  before_action :set_source, only: [:show, :edit, :update, :destroy]

  def index
    @sources = NewsSource.all
  end

  def show
  end

  def new
    @source = NewsSource.new
  end

  def edit
  end

  def create
    @source = NewsSource.new(source_params)

    if @source.save
      redirect_to admin_news_source_path(@source), notice: 'News source was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @source.update(source_params)
      redirect_to admin_news_source_path(@source), notice: 'News source was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @source.destroy
    redirect_to admin_news_sources_path, notice: 'News source was successfully destroyed.'
  end

  private

  def set_source
    @source = NewsSource.find(params[:id])
  end

  def source_params
    params.require(:news_source).permit(:name, :url, :format, :active, settings: {})
  end
end