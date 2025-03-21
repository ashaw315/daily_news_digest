class CreateApis < ActiveRecord::Migration[7.1]
  def change
    create_table :apis do |t|
      t.string :name, null: false
      t.string :endpoint, null: false
      t.integer :priority, default: 0

      t.timestamps
      
      t.index :name, unique: true
      t.index :priority
    end
  end
end
