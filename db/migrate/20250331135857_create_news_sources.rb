class CreateNewsSources < ActiveRecord::Migration[7.1]
  def change
    create_table :news_sources do |t|
      t.string :name
      t.string :url
      t.string :format
      t.boolean :active
      t.jsonb :settings

      t.timestamps
    end
  end
end
