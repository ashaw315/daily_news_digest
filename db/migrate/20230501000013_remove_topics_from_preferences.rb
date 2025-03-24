class RemoveTopicsFromPreferences < ActiveRecord::Migration[7.0]
    def change
      remove_column :preferences, :topics, :text
    end
  end