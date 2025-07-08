# Supabase Setup Guide

## Current Status
✅ RLS (Row Level Security) has been enabled on all tables in your local database
✅ Migration created to handle both local PostgreSQL and Supabase environments
✅ Comprehensive RLS policies ready for Supabase deployment
✅ **Supabase CLI installed and configured**
✅ **Local RLS policies applied and tested**
✅ **Application fully functional with RLS enabled**

## When Moving to Supabase

### 1. Set up Supabase Database
1. Create a new project in [Supabase](https://supabase.com)
2. Note your database URL, API URL, and service role key

### 2. Update Database Configuration
Update your `config/database.yml` production section:

```yaml
production:
  <<: *default
  url: <%= ENV["DATABASE_URL"] %>
```

Set the `DATABASE_URL` environment variable to your Supabase connection string:
```
DATABASE_URL=postgresql://postgres:[PASSWORD]@[HOST]:[PORT]/postgres
```

### 3. Migrate Your Schema
```bash
# Set your Supabase DATABASE_URL
export DATABASE_URL="your_supabase_connection_string"

# Run migrations to create all tables
rails db:migrate RAILS_ENV=production
```

### 4. Apply RLS Policies
Run the SQL file `db/supabase_rls_policies.sql` in your Supabase SQL editor:

1. Go to your Supabase dashboard
2. Navigate to SQL Editor
3. Copy and paste the contents of `db/supabase_rls_policies.sql`
4. Run the SQL

### 5. Configure Authentication (Optional)
If you want to use Supabase Auth instead of Devise:

1. Install supabase-rb gem
2. Configure Supabase client
3. Update authentication logic

## RLS Policies Overview

### Security Model
- **Users**: Can only access their own data, admins can access all
- **Articles**: All authenticated users can read, only admins can modify
- **News Sources**: All authenticated users can read, only admins can modify
- **Topics**: All authenticated users can read, only admins can modify
- **User Associations**: Users can only access their own associations
- **Email Data**: Users can only access their own email tracking/metrics
- **APIs**: Admin-only access
- **Service Role**: Bypasses RLS for server operations (your Rails app)

### Tables with RLS Enabled
- `users`
- `articles`
- `news_sources`
- `topics`
- `user_news_sources`
- `user_topics`
- `preferences`
- `email_trackings`
- `email_metrics`
- `apis`

## Testing RLS
After applying policies, test with:

```sql
-- Test as a regular user (should only see own data)
SELECT * FROM users WHERE id = auth.uid();

-- Test article access (should see all articles)
SELECT * FROM articles LIMIT 5;
```

## Troubleshooting

### If you get "permission denied" errors:
1. Check that service role policies are applied
2. Verify your Rails app is using the service role key
3. Ensure FORCE ROW LEVEL SECURITY is set correctly

### If policies are too restrictive:
1. Review the policy SQL in `db/supabase_rls_policies.sql`
2. Modify policies as needed for your use case
3. Re-run the SQL in Supabase

### Bypassing RLS for Development:
```sql
-- Temporarily disable RLS on a table
ALTER TABLE table_name DISABLE ROW LEVEL SECURITY;

-- Re-enable when ready
ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;
```

## Environment Variables for Supabase
```bash
DATABASE_URL=postgresql://postgres:[PASSWORD]@[HOST]:[PORT]/postgres
SUPABASE_URL=https://[PROJECT_ID].supabase.co
SUPABASE_ANON_KEY=[ANON_KEY]
SUPABASE_SERVICE_ROLE_KEY=[SERVICE_KEY]
```