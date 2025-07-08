class EnableRowLevelSecurity < ActiveRecord::Migration[7.1]
  def up
    # Check if we're in a Supabase environment (has auth schema)
    is_supabase = connection.schema_exists?('auth')
    
    if is_supabase
      enable_rls_for_supabase
    else
      # For local development, just enable RLS without policies
      # Policies can be added when migrating to Supabase
      enable_rls_basic
    end
  end

  def down
    # Disable RLS on all tables
    tables_for_rls.each do |table_name|
      execute "ALTER TABLE #{table_name} DISABLE ROW LEVEL SECURITY;"
    end
  end

  private

  def tables_for_rls
    %w[
      users
      articles
      news_sources
      topics
      user_news_sources
      user_topics
      preferences
      email_trackings
      email_metrics
      apis
    ]
  end

  def enable_rls_basic
    # Just enable RLS for local development
    tables_for_rls.each do |table_name|
      execute "ALTER TABLE #{table_name} ENABLE ROW LEVEL SECURITY;"
    end
    
    say "RLS enabled on all tables. When moving to Supabase, run 'rails db:migrate:reset' to apply full policies."
  end

  def enable_rls_for_supabase
    # Enable RLS on all user-accessible tables
    tables_for_rls.each do |table_name|
      execute "ALTER TABLE #{table_name} ENABLE ROW LEVEL SECURITY;"
    end

    # Create RLS policies for each table
    create_user_policies
    create_article_policies
    create_news_source_policies
    create_topic_policies
    create_preference_policies
    create_association_policies
    create_email_policies
    create_api_policies
    
    say "RLS enabled with full Supabase policies."
  end

  def create_user_policies
    # Users can only access their own records
    execute <<-SQL
      CREATE POLICY "users_own_data" ON users
        FOR ALL
        USING (auth.uid()::text = id::text);
    SQL

    # Admin users can access all user records
    execute <<-SQL
      CREATE POLICY "admin_full_access" ON users
        FOR ALL
        USING (
          EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id::text = auth.uid()::text 
            AND u.admin = true
          )
        );
    SQL
  end

  def create_article_policies
    # All authenticated users can read articles
    execute <<-SQL
      CREATE POLICY "articles_read_all" ON articles
        FOR SELECT
        USING (auth.role() = 'authenticated');
    SQL

    # Only admins can modify articles
    execute <<-SQL
      CREATE POLICY "articles_admin_modify" ON articles
        FOR ALL
        USING (
          EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id::text = auth.uid()::text 
            AND u.admin = true
          )
        );
    SQL
  end

  def create_news_source_policies
    # All authenticated users can read news sources
    execute <<-SQL
      CREATE POLICY "news_sources_read_all" ON news_sources
        FOR SELECT
        USING (auth.role() = 'authenticated');
    SQL

    # Only admins can modify news sources
    execute <<-SQL
      CREATE POLICY "news_sources_admin_modify" ON news_sources
        FOR INSERT, UPDATE, DELETE
        USING (
          EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id::text = auth.uid()::text 
            AND u.admin = true
          )
        );
    SQL
  end

  def create_topic_policies
    # All authenticated users can read topics
    execute <<-SQL
      CREATE POLICY "topics_read_all" ON topics
        FOR SELECT
        USING (auth.role() = 'authenticated');
    SQL

    # Only admins can modify topics
    execute <<-SQL
      CREATE POLICY "topics_admin_modify" ON topics
        FOR INSERT, UPDATE, DELETE
        USING (
          EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id::text = auth.uid()::text 
            AND u.admin = true
          )
        );
    SQL
  end

  def create_preference_policies
    # Users can only access their own preferences
    execute <<-SQL
      CREATE POLICY "preferences_own_data" ON preferences
        FOR ALL
        USING (auth.uid()::text = user_id::text);
    SQL

    # Admins can access all preferences
    execute <<-SQL
      CREATE POLICY "preferences_admin_access" ON preferences
        FOR ALL
        USING (
          EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id::text = auth.uid()::text 
            AND u.admin = true
          )
        );
    SQL
  end

  def create_association_policies
    # User-news source associations
    execute <<-SQL
      CREATE POLICY "user_news_sources_own_data" ON user_news_sources
        FOR ALL
        USING (auth.uid()::text = user_id::text);
    SQL

    execute <<-SQL
      CREATE POLICY "user_news_sources_admin_access" ON user_news_sources
        FOR ALL
        USING (
          EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id::text = auth.uid()::text 
            AND u.admin = true
          )
        );
    SQL

    # User-topic associations
    execute <<-SQL
      CREATE POLICY "user_topics_own_data" ON user_topics
        FOR ALL
        USING (auth.uid()::text = user_id::text);
    SQL

    execute <<-SQL
      CREATE POLICY "user_topics_admin_access" ON user_topics
        FOR ALL
        USING (
          EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id::text = auth.uid()::text 
            AND u.admin = true
          )
        );
    SQL
  end

  def create_email_policies
    # Email tracking - users can only access their own
    execute <<-SQL
      CREATE POLICY "email_trackings_own_data" ON email_trackings
        FOR ALL
        USING (auth.uid()::text = user_id::text);
    SQL

    execute <<-SQL
      CREATE POLICY "email_trackings_admin_access" ON email_trackings
        FOR ALL
        USING (
          EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id::text = auth.uid()::text 
            AND u.admin = true
          )
        );
    SQL

    # Email metrics - users can only access their own
    execute <<-SQL
      CREATE POLICY "email_metrics_own_data" ON email_metrics
        FOR ALL
        USING (auth.uid()::text = user_id::text);
    SQL

    execute <<-SQL
      CREATE POLICY "email_metrics_admin_access" ON email_metrics
        FOR ALL
        USING (
          EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id::text = auth.uid()::text 
            AND u.admin = true
          )
        );
    SQL
  end

  def create_api_policies
    # API access - only admins can access
    execute <<-SQL
      CREATE POLICY "apis_admin_only" ON apis
        FOR ALL
        USING (
          EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id::text = auth.uid()::text 
            AND u.admin = true
          )
        );
    SQL
  end
end
