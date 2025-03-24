class Admin::EmailMetricsController < Admin::BaseController
  def index
    @email_metrics = EmailMetric.all.order(created_at: :desc)
    
    @summary = {
      sent: EmailMetric.where(status: 'sent').count,
      opened: EmailMetric.where(status: 'opened').count,
      clicked: EmailMetric.where(status: 'clicked').count,
      failed: EmailMetric.where(status: 'failed').count
    }
    
    @daily_metrics = EmailMetric.where('created_at > ?', 30.days.ago)
                               .group("DATE(created_at)")
                               .group(:status)
                               .count
  end
end 