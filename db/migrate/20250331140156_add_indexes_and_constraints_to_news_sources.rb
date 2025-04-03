class AddIndexesAndConstraintsToNewsSources < ActiveRecord::Migration[7.1]
  def change
     # Add NOT NULL constraints
     change_column_null :news_sources, :name, false
     change_column_null :news_sources, :format, false
     
     # Add default values
     change_column_default :news_sources, :active, true
     change_column_default :news_sources, :settings, {}
     
     # Add indexes
     add_index :news_sources, :name, unique: true
     add_index :news_sources, :format
     add_index :news_sources, :active
  end
end
