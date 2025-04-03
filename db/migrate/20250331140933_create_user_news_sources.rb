class CreateUserNewsSources < ActiveRecord::Migration[7.1]
  def change
    create_table :user_news_sources do |t|
      t.references :user, null: false, foreign_key: true
      t.references :news_source, null: false, foreign_key: true

      t.timestamps
    end

    # Add a unique index to prevent duplicate associations
    add_index :user_news_sources, [:user_id, :news_source_id], unique: true
  end
end
