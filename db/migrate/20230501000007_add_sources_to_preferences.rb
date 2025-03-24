class AddSourcesToPreferences < ActiveRecord::Migration[7.0]
    def change
      add_column :preferences, :sources, :text
    end
  end