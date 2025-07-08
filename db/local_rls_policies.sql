-- Local PostgreSQL RLS Policies (without Supabase auth functions)
-- This version works with local PostgreSQL databases

-- RLS is already enabled by migration, but let's ensure it's set correctly
-- ALTER TABLE users ENABLE ROW LEVEL SECURITY;
-- (already done by migration)

-- For local development, we'll create more permissive policies
-- since we don't have Supabase auth.uid() function

-- Drop any existing policies first (in case we're re-running)
DROP POLICY IF EXISTS "users_own_data" ON users;
DROP POLICY IF EXISTS "admin_full_access_users" ON users;
DROP POLICY IF EXISTS "articles_read_all" ON articles;
DROP POLICY IF EXISTS "articles_admin_modify" ON articles;
DROP POLICY IF EXISTS "news_sources_read_all" ON news_sources;
DROP POLICY IF EXISTS "news_sources_admin_modify" ON news_sources;
DROP POLICY IF EXISTS "topics_read_all" ON topics;
DROP POLICY IF EXISTS "topics_admin_modify" ON topics;
DROP POLICY IF EXISTS "preferences_own_data" ON preferences;
DROP POLICY IF EXISTS "preferences_admin_access" ON preferences;
DROP POLICY IF EXISTS "user_news_sources_own_data" ON user_news_sources;
DROP POLICY IF EXISTS "user_news_sources_admin_access" ON user_news_sources;
DROP POLICY IF EXISTS "user_topics_own_data" ON user_topics;
DROP POLICY IF EXISTS "user_topics_admin_access" ON user_topics;
DROP POLICY IF EXISTS "email_trackings_own_data" ON email_trackings;
DROP POLICY IF EXISTS "email_trackings_admin_access" ON email_trackings;
DROP POLICY IF EXISTS "email_metrics_own_data" ON email_metrics;
DROP POLICY IF EXISTS "email_metrics_admin_access" ON email_metrics;
DROP POLICY IF EXISTS "apis_admin_only" ON apis;

-- Create local development policies (more permissive for testing)
-- These allow your Rails app to work normally while RLS is enabled

-- Users table - allow all access for local development
CREATE POLICY "local_dev_users_access" ON users
  FOR ALL
  USING (true);

-- Articles table - allow all access for local development
CREATE POLICY "local_dev_articles_access" ON articles
  FOR ALL
  USING (true);

-- News sources table - allow all access
CREATE POLICY "local_dev_news_sources_access" ON news_sources
  FOR ALL
  USING (true);

-- Topics table - allow all access
CREATE POLICY "local_dev_topics_access" ON topics
  FOR ALL
  USING (true);

-- Preferences table - allow all access
CREATE POLICY "local_dev_preferences_access" ON preferences
  FOR ALL
  USING (true);

-- User-news source associations - allow all access
CREATE POLICY "local_dev_user_news_sources_access" ON user_news_sources
  FOR ALL
  USING (true);

-- User-topic associations - allow all access
CREATE POLICY "local_dev_user_topics_access" ON user_topics
  FOR ALL
  USING (true);

-- Email tracking - allow all access
CREATE POLICY "local_dev_email_trackings_access" ON email_trackings
  FOR ALL
  USING (true);

-- Email metrics - allow all access
CREATE POLICY "local_dev_email_metrics_access" ON email_metrics
  FOR ALL
  USING (true);

-- API access - allow all access
CREATE POLICY "local_dev_apis_access" ON apis
  FOR ALL
  USING (true);

-- Output success message
\echo 'Local RLS policies created successfully!'
\echo 'These policies allow full access for local development.'
\echo 'When deploying to Supabase, use db/supabase_rls_policies.sql instead.'