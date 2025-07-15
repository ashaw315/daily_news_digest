class Admin::EmailMetricsController < Admin::BaseController
  def index
    # Add pagination to prevent memory issues with kaminari
    @email_metrics = EmailMetric.includes(:user)
                               .order(created_at: :desc)
                               .page(params[:page])
                               .per(50)
    
    @summary = {
      sent: EmailMetric.where(status: 'sent').count,
      opened: EmailMetric.where(status: 'opened').count,
      clicked: EmailMetric.where(status: 'clicked').count,
      failed: EmailMetric.where(status: 'failed').count
    }
    
    # Limit daily metrics to recent data for performance
    @daily_metrics = EmailMetric.where('created_at > ?', 7.days.ago)
                               .group("DATE(created_at)")
                               .group(:status)
                               .count
  end
end 