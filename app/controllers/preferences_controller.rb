class PreferencesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user

  def edit
    @user = current_user
    @topics = Topic.active
    @news_sources = NewsSource.active
  end

  def update
    @user = current_user
    
    if @user.update(user_params)
      redirect_to edit_preferences_path, notice: 'Preferences updated successfully'
    else
      @topics = Topic.active
      @news_sources = NewsSource.active

       Rails.logger.debug "UPDATE FAILED: #{@user.errors.full_messages}"
      
      # Return a 422 status code for Turbo to handle
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  def reset
    if @user.reset_preferences!
      # Add debugging
      Rails.logger.info "Reset successful, redirecting to: #{edit_preferences_path}"
      
      respond_to do |format|
        format.html { redirect_to edit_preferences_path, notice: "Preferences have been reset" }
        format.turbo_stream { redirect_to edit_preferences_path, notice: "Preferences have been reset" }
      end
    else
      Rails.logger.info "Reset failed"
      redirect_to edit_preferences_path, alert: "Unable to reset preferences"
    end
  end

  private

  def set_user
    @user = current_user
  end

  def user_params
    params.require(:user).permit(
      topic_ids: [], 
      news_source_ids: [],
      preferences_attributes: [:id, :email_frequency, :dark_mode]
    )
  end
end
