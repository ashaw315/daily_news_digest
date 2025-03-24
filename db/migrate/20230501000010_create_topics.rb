class CreateTopics < ActiveRecord::Migration[7.0]
    def change
      create_table :topics do |t|
        t.string :name, null: false
        t.boolean :active, default: true
        
        t.timestamps
      end
      
      add_index :topics, :name, unique: true
    end
  end