class AddUnsubscribeTokenToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :unsubscribe_token, :string
  end
end
