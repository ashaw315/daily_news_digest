-- Supabase Row Level Security (RLS) Policies
-- Run this SQL in your Supabase SQL editor after migrating your schema

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE news_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_news_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_trackings ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE apis ENABLE ROW LEVEL SECURITY;

-- Users table policies
CREATE POLICY "users_own_data" ON users
  FOR ALL
  USING (auth.uid()::text = id::text);

CREATE POLICY "admin_full_access_users" ON users
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id::text = auth.uid()::text 
      AND u.admin = true
    )
  );

-- Articles table policies
CREATE POLICY "articles_read_all" ON articles
  FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "articles_admin_modify" ON articles
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id::text = auth.uid()::text 
      AND u.admin = true
    )
  );

-- News sources table policies
CREATE POLICY "news_sources_read_all" ON news_sources
  FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "news_sources_admin_modify" ON news_sources
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id::text = auth.uid()::text 
      AND u.admin = true
    )
  );

-- Topics table policies
CREATE POLICY "topics_read_all" ON topics
  FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "topics_admin_modify" ON topics
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id::text = auth.uid()::text 
      AND u.admin = true
    )
  );

-- User preferences policies
CREATE POLICY "preferences_own_data" ON preferences
  FOR ALL
  USING (auth.uid()::text = user_id::text);

CREATE POLICY "preferences_admin_access" ON preferences
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id::text = auth.uid()::text 
      AND u.admin = true
    )
  );

-- User-news source associations policies
CREATE POLICY "user_news_sources_own_data" ON user_news_sources
  FOR ALL
  USING (auth.uid()::text = user_id::text);

CREATE POLICY "user_news_sources_admin_access" ON user_news_sources
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id::text = auth.uid()::text 
      AND u.admin = true
    )
  );

-- User-topic associations policies
CREATE POLICY "user_topics_own_data" ON user_topics
  FOR ALL
  USING (auth.uid()::text = user_id::text);

CREATE POLICY "user_topics_admin_access" ON user_topics
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id::text = auth.uid()::text 
      AND u.admin = true
    )
  );

-- Email tracking policies
CREATE POLICY "email_trackings_own_data" ON email_trackings
  FOR ALL
  USING (auth.uid()::text = user_id::text);

CREATE POLICY "email_trackings_admin_access" ON email_trackings
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id::text = auth.uid()::text 
      AND u.admin = true
    )
  );

-- Email metrics policies
CREATE POLICY "email_metrics_own_data" ON email_metrics
  FOR ALL
  USING (auth.uid()::text = user_id::text);

CREATE POLICY "email_metrics_admin_access" ON email_metrics
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id::text = auth.uid()::text 
      AND u.admin = true
    )
  );

-- API access policies (admin only)
CREATE POLICY "apis_admin_only" ON apis
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id::text = auth.uid()::text 
      AND u.admin = true
    )
  );

-- Grant necessary permissions for service role (used by your Rails app)
GRANT USAGE ON SCHEMA public TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- Allow service role to bypass RLS (for your Rails application)
ALTER TABLE users FORCE ROW LEVEL SECURITY;
ALTER TABLE articles FORCE ROW LEVEL SECURITY;
ALTER TABLE news_sources FORCE ROW LEVEL SECURITY;
ALTER TABLE topics FORCE ROW LEVEL SECURITY;
ALTER TABLE user_news_sources FORCE ROW LEVEL SECURITY;
ALTER TABLE user_topics FORCE ROW LEVEL SECURITY;
ALTER TABLE preferences FORCE ROW LEVEL SECURITY;
ALTER TABLE email_trackings FORCE ROW LEVEL SECURITY;
ALTER TABLE email_metrics FORCE ROW LEVEL SECURITY;
ALTER TABLE apis FORCE ROW LEVEL SECURITY;

-- Create service role policy to bypass RLS for server operations
CREATE POLICY "service_role_bypass" ON users
  FOR ALL
  TO service_role
  USING (true);

CREATE POLICY "service_role_bypass" ON articles
  FOR ALL
  TO service_role
  USING (true);

CREATE POLICY "service_role_bypass" ON news_sources
  FOR ALL
  TO service_role
  USING (true);

CREATE POLICY "service_role_bypass" ON topics
  FOR ALL
  TO service_role
  USING (true);

CREATE POLICY "service_role_bypass" ON user_news_sources
  FOR ALL
  TO service_role
  USING (true);

CREATE POLICY "service_role_bypass" ON user_topics
  FOR ALL
  TO service_role
  USING (true);

CREATE POLICY "service_role_bypass" ON preferences
  FOR ALL
  TO service_role
  USING (true);

CREATE POLICY "service_role_bypass" ON email_trackings
  FOR ALL
  TO service_role
  USING (true);

CREATE POLICY "service_role_bypass" ON email_metrics
  FOR ALL
  TO service_role
  USING (true);

CREATE POLICY "service_role_bypass" ON apis
  FOR ALL
  TO service_role
  USING (true);