class CreateArticles < ActiveRecord::Migration[7.1]
  def change
    create_table :articles do |t|
      t.string :title, null: false
      t.text :summary
      t.string :url, null: false
      t.datetime :publish_date
      t.string :source
      t.string :topic

      t.timestamps
      
      t.index :publish_date
      t.index :topic
      t.index :source
    end
  end
end
