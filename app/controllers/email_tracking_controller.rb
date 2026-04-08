class EmailTrackingController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token

  # 1x1 transparent GIF (43 bytes)
  TRACKING_GIF = Base64.decode64(
    "R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"
  ).freeze

  def track
    tracking = EmailTracking.find_by(token: params[:token])

    if tracking
      tracking.increment!(:open_count)
      tracking.update_column(:opened_at, Time.current) if tracking.opened_at.nil?
      Rails.logger.info("[EmailTracking] Open recorded for user #{tracking.user_id}, token: #{params[:token]}")
    else
      Rails.logger.warn("[EmailTracking] Unknown token: #{params[:token]}")
    end

    send_data TRACKING_GIF, type: "image/gif", disposition: "inline"
  end
end
