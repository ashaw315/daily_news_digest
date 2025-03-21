class AddPreferencesToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :preferences, :jsonb, null: false, default: {}
    add_column :users, :is_subscribed, :boolean, null: false, default: false
    add_index :users, :is_subscribed
  end
end
