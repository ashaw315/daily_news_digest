class Admin::DashboardController < Admin::BaseController
  def index
    @user_count = User.count
    @article_count = Article.count
    @source_count = NewsSource.count
    @email_metrics = {
      sent: EmailMetric.where(status: 'sent').count,
      opened: EmailMetric.where(status: 'opened').count,
      clicked: EmailMetric.where(status: 'clicked').count,
      failed: EmailMetric.where(status: 'failed').count
    }
  end
end 