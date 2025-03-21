class CreateEmailTrackings < ActiveRecord::Migration[7.1]
  def change
    create_table :email_trackings do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :open_count, default: 0
      t.integer :click_count, default: 0

      t.timestamps
      
      t.index [:user_id, :created_at]
    end
  end
end
