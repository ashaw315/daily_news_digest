# Claude Instructions for Daily News Digest

## Project Overview
A Ruby on Rails application for aggregating and managing daily news articles. The application includes admin functionality, news fetching services, and cron job management.

## Key Commands
- `rails server` - Start the development server
- `rails console` - Access Rails console
- `rails test` - Run tests
- `bundle install` - Install dependencies
- `rails db:migrate` - Run database migrations
- `rails db:seed` - Seed the database

## Project Structure
- `app/controllers/admin/` - Admin interface controllers
- `app/services/` - Service classes for news fetching and validation
- `lib/tasks/` - Rake tasks including cron jobs
- `config/routes.rb` - Application routes

## Recent Changes
- Added cron job endpoints and admin routes
- Enhanced news fetching service with validation
- Streamlined deployment by removing Redis/Sidekiq
- Updated email delivery configuration for production
- Fixed news source preview to display AI-generated summaries

## Testing
Run `rails test` to execute the test suite.

### Cron Job Testing
Test cron jobs individually:
- `rails cron_test:fetch_articles` - Test article fetching
- `rails cron_test:schedule_daily_emails` - Test email scheduling
- `rails cron_test:purge_articles` - Test old article deletion
- `rails cron_test:all` - Run all cron job tests

### Cron Job Configuration
- **Fetch Articles**: Runs daily at 7:00 AM, fetches ONLY from sources that have subscribed users
- **Schedule Daily Emails**: Runs daily at 8:00 AM, uses async queue adapter in development
- **Purge Articles**: Runs daily at 2:00 AM, removes articles older than 24 hours
- **Weekly Emails**: Runs Fridays at 8:00 AM

### Important Note
The cron job will only fetch articles from NewsSource that have at least one subscribed user. This is efficient and prevents unnecessary API calls to sources that no one is subscribed to.

## Database Security
✅ **Row Level Security (RLS)** is enabled on all tables for Supabase compatibility.
✅ **Supabase CLI** is installed and configured.
✅ **Local RLS policies** are applied and working.

### RLS Status
All user-accessible tables have RLS enabled with policies:
- `users`, `articles`, `news_sources`, `topics`
- `user_news_sources`, `user_topics`, `preferences` 
- `email_trackings`, `email_metrics`, `apis`

### Local Development
- RLS is enabled with permissive policies for local development
- All application functionality works correctly
- Cron jobs and data access fully functional

### Supabase Migration
When connecting to Supabase:
1. Run `db/supabase_rls_policies.sql` in Supabase SQL editor
2. See `SUPABASE_SETUP.md` for detailed migration guide

## Deployment
The application is configured for deployment on Render with the configuration in `render.yaml`.
For Supabase deployment, see `SUPABASE_SETUP.md`.