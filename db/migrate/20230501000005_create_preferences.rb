class CreatePreferences < ActiveRecord::Migration[7.0]
  def change
    create_table :preferences do |t|
      t.references :user, null: false, foreign_key: true
      t.text :topics
      t.string :email_frequency, default: 'daily'
      t.boolean :dark_mode, default: false
      
      t.timestamps
    end
  end
end 