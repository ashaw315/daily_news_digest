class AddTopicToNewsSources < ActiveRecord::Migration[7.1]
  def change
    add_reference :news_sources, :topic, foreign_key: true
  end
end
