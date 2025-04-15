class DropSourcesTable < ActiveRecord::Migration[7.1]
  def up
    drop_table :sources
  end

  def down
    create_table :sources do |t|
      t.string :name, null: false
      t.string :url, null: false
      t.string :source_type, null: false
      t.boolean :active, default: true
      t.text :selectors
      t.timestamps
    end
  end
end
