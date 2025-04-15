class AddNewsSourceIdToArticles < ActiveRecord::Migration[7.1]
  def change
    add_reference :articles, :news_source, foreign_key: true, null: true

    # You can uncomment these lines after you've assigned news sources to all articles
    # change_column_null :articles, :news_source_id, false
  end
end
