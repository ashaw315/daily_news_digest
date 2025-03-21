class PreferencesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user

  def edit
    # Add available news sources for the view
    @news_sources = NewsFetcher.new.sources.map { |s| s[:name] }
  end

  def update
    if @user.update(user_params)
      redirect_to edit_preferences_path, notice: 'Preferences updated successfully'
    else
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
      preferences: {
        topics: [],
        sources: [],
        frequency: []
      }
    )
  end
end
