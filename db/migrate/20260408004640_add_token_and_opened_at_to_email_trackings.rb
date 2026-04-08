class AddTokenAndOpenedAtToEmailTrackings < ActiveRecord::Migration[7.1]
  def change
    add_column :email_trackings, :token, :string
    add_column :email_trackings, :opened_at, :datetime
    add_index :email_trackings, :token, unique: true
  end
end
