class AddHealthMetricsToNewsSources < ActiveRecord::Migration[7.1]
  def change
    add_column :news_sources, :last_fetched_at, :datetime
    add_column :news_sources, :last_fetch_status, :string
    add_column :news_sources, :last_fetch_article_count, :integer
    add_column :news_sources, :last_fetch_errors, :text
  end
end
