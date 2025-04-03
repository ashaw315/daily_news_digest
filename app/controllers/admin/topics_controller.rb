class Admin::TopicsController < Admin::BaseController
  before_action :set_topic, only: [:show, :edit, :update, :destroy]

  def index
    @topics = Topic.all
  end

  def show
  end

  def new
    @topic = Topic.new
  end

  def edit
  end

  def create
    @topic = Topic.new(topic_params)

    if @topic.save
      redirect_to admin_topic_path(@topic), notice: 'Topic was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @topic.update(topic_params)
      redirect_to admin_topic_path(@topic), notice: 'Topic was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @topic.destroy
    redirect_to admin_topics_path, notice: 'Topic was successfully destroyed.'
  end

  private

  def set_topic
    @topic = Topic.find(params[:id])
  end

  def topic_params
    params.require(:topic).permit(:name, :description, :active)
  end
end