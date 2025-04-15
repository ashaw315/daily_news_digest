class AssignNewsSourcesAndMakeNonNull < ActiveRecord::Migration[7.1]
  def up
    # First, find or create a default news source for orphaned articles
    default_source = NewsSource.find_or_create_by!(
      name: 'Legacy Source',
      url: 'https://legacy.example.com',
      format: 'rss',
      active: false
    )

    # Assign the default source to all articles that don't have one
    execute <<-SQL
      UPDATE articles 
      SET news_source_id = #{default_source.id} 
      WHERE news_source_id IS NULL;
    SQL

    # Now we can safely make the column non-null
    change_column_null :articles, :news_source_id, false
  end

  def down
    change_column_null :articles, :news_source_id, true
  end
end
