---
TITLE: Daily News Digest
TAGLINE: A personalized news aggregator that fetches, summarizes, and delivers daily email digests from RSS sources users actually subscribe to.
SECTION: project
STACK: Ruby on Rails 7.1, PostgreSQL, OpenAI GPT-3.5, Feedjira, Devise, Resend, Render, GitHub Actions, Supabase RLS
LIVE_URL: https://daily-news-digest.onrender.com (fetch pipeline currently inactive due to Render free-tier inactivity timeout)
GITHUB_URL: https://github.com/ashaw315/daily_news_digest
---

## Description

Daily News Digest solves a simple problem: most news aggregators show you everything. This one only fetches what someone is actually waiting to read. Users sign up, choose their RSS sources, and receive a daily email digest with AI-generated summaries of each article.

The application handles the full pipeline: scheduled fetching from RSS feeds, full-text extraction with Readability, summarization via OpenAI, and email delivery through Resend. An admin interface provides source management with live RSS validation, article previews with AI summaries, user administration, and email delivery metrics.

The system was designed to run within tight infrastructure constraints — a 512MB Render instance with no background worker processes and no paid add-ons beyond the database. That constraint shaped most of the interesting architectural decisions: Sidekiq was removed in favor of Rails' built-in async adapter, memory monitoring is woven through every service class, article counts are hard-capped at every stage, and background jobs run in-process instead of requiring a separate worker.

## Technical Note

The most considered decision in this codebase is the subscriber-gated fetch. The daily cron job doesn't pull from all active news sources — it only fetches from sources that have at least one subscribed user. The query lives in `app/controllers/admin/cron_controller.rb`:

```ruby
active_sources = NewsSource.joins(:users)
                          .where(users: { is_subscribed: true })
                          .where(active: true)
                          .where.not(url: [nil, ''])
                          .distinct
```

This is a deliberate choice, not an optimization afterthought. RSS fetching involves HTTP requests, HTML parsing, content extraction, and database writes for each source. On a free-tier instance with hard memory limits, every unnecessary fetch is a risk — both to response time and to staying under the 512MB ceiling. By gating on subscriber presence, the system only does work that will result in an email someone receives.

The same constraint-driven thinking shows up elsewhere. The email pipeline was migrated from SendGrid to Gmail SMTP, then to Resend's API — eliminating SMTP connection issues on Render's free tier. Sidekiq was removed in favor of Rails' built-in async adapter — one fewer process, one fewer service to pay for, and sufficient at current subscriber counts. Memory is tracked with explicit thresholds (350/400/450 MB) across `ArticleFetcher`, `DailyEmailJob`, `ParallelArticleProcessor`, and a dedicated `MemoryMonitor` service, with forced garbage collection between batches.

The cron endpoints also implement distributed task locking to prevent duplicate concurrent runs. The `with_task_lock` method in `CronController` writes a lock key to `Rails.cache` with a 30-minute TTL before executing, returns a 409 Conflict if the lock already exists, and cleans up in an `ensure` block so locks don't go stale on errors. It's a lightweight alternative to Redis-based locking that fits the minimal-infrastructure constraint.

The database layer includes Row Level Security policies (`db/supabase_rls_policies.sql`) for Supabase compatibility. RLS is enabled on all ten tables with user-scoped read/write policies, admin bypass, and service role pass-through for the Rails application. This was set up proactively for a potential migration to Supabase-hosted Postgres, where RLS enforcement is non-optional.

The CI pipeline runs RSpec with Capybara browser tests via GitHub Actions, including Chrome/Chromedriver setup and screenshot capture on failure. The workflow is configured but may need re-activation if the repository has been dormant.
