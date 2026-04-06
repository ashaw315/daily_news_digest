# Daily News Digest

A Rails application that aggregates news from RSS feeds, generates AI summaries, and delivers personalized daily or weekly email digests to subscribers.

Users choose their news sources, and the system handles the rest: fetching articles on a schedule, summarizing them with OpenAI, and sending formatted digests via email.

## Tech Stack

- **Framework:** Ruby on Rails 7.1
- **Database:** PostgreSQL (with Supabase RLS compatibility)
- **AI:** OpenAI GPT-3.5 (article summarization)
- **RSS Parsing:** Feedjira, Nokogiri, ruby-readability
- **Authentication:** Devise
- **Email:** Gmail SMTP (migrated from SendGrid)
- **Background Jobs:** Active Job with async adapter (no Redis required)
- **Deployment:** Render (free tier, 512MB)
- **CI:** GitHub Actions (RSpec + Capybara)

## How It Works

### Fetch Pipeline

A scheduled cron job runs daily at 7:00 AM. It queries only the news sources that have at least one active subscriber, fetches up to 3 articles per source via RSS, extracts full article text with Readability, and persists them to the database. Sources with zero subscribers are skipped entirely.

### Email Delivery

At 8:00 AM, a second cron job schedules email jobs for each subscribed user. Each job fetches the user's articles (3 per source, 30 max), runs them through the AI summarizer, and sends a formatted digest. A 1-second delay between sends keeps Gmail rate limits in check.

Weekly digests run on Fridays. A purge job at 2:00 AM removes articles older than 24 hours.

### Memory Management

The app runs on a 512MB Render instance. Memory is actively monitored throughout the pipeline with thresholds at 350/400/450 MB. Garbage collection is forced between batches, article counts are hard-capped, and AI processing runs sequentially in production (1 thread) to stay within limits.

### Admin Interface

An admin dashboard at `/admin` provides news source management (with RSS validation and article preview), user administration, email metrics tracking, and HTTP endpoints for triggering cron jobs externally.

## Architecture Overview

```
Cron (7:00 AM)
  └─ fetch_articles
       └─ NewsSource.joins(:users).where(is_subscribed: true) ← subscriber gate
       └─ EnhancedNewsFetcher → Feedjira → Readability → Article records

Cron (8:00 AM)
  └─ schedule_daily_emails
       └─ DailyEmailJob (per user)
            └─ ArticleFetcher → 3 articles/source, 30 max
            └─ ParallelArticleProcessor → AiSummarizerService (OpenAI)
            └─ DailyNewsMailer → Gmail SMTP

Cron (2:00 AM)
  └─ purge_articles → delete articles > 24h old
```

Key service classes:

| Service | Purpose |
|---------|---------|
| `EnhancedNewsFetcher` | RSS parsing, content extraction, article persistence |
| `ArticleFetcher` | Per-user article retrieval with memory limits |
| `AiSummarizerService` | OpenAI integration with rate limiting and fallback |
| `ParallelArticleProcessor` | Concurrent AI processing with timeouts |
| `MemoryMonitor` | RSS memory tracking against 512MB ceiling |
| `SourceValidatorService` | RSS feed validation before saving sources |

## Local Setup

### Prerequisites

- Ruby 3.2.2
- PostgreSQL 14+
- An OpenAI API key
- A Gmail account with an app password (for email delivery)

### Install

```bash
git clone https://github.com/ashaw315/daily_news_digest.git
cd daily_news_digest
bundle install
rails db:create db:migrate db:seed
```

### Environment Variables

Create a `.env` file or set these in your shell:

```
OPENAI_API_KEY=your_openai_key
GMAIL_USERNAME=your_email@gmail.com
GMAIL_APP_PASSWORD=your_app_password
CRON_API_KEY=any_secret_string
RAILS_MASTER_KEY=from_config/master.key
```

### Run

```bash
rails server
```

Admin access requires the `admin` flag on a user record. Set it via the console:

```ruby
User.find_by(email: "you@example.com").update(admin: true)
```

### Test

```bash
rails test                          # Full suite
rails cron_test:fetch_articles      # Test article fetching
rails cron_test:schedule_daily_emails  # Test email scheduling
rails cron_test:all                 # All cron job tests
```

## Deployment

Deployed on Render using the included `render.yaml`. The configuration provisions a free-tier web service and PostgreSQL database. Cron jobs are triggered via HTTP endpoints at `/admin/cron/*`, authenticated with an API key (`X-API-KEY` header).

The Procfile defines three processes, though the worker process (Sidekiq) was removed from the production path in favor of Rails' built-in async adapter — one fewer moving part.

### Supabase (Optional)

Row Level Security policies are defined in `db/supabase_rls_policies.sql` for optional Supabase deployment. RLS is enabled on all user-accessible tables with admin bypass and service role policies. See `SUPABASE_SETUP.md` for migration instructions.

## Notable Decisions

- **SendGrid → Gmail SMTP**: Migrated away from SendGrid to simplify the email stack. Gmail's 500/day limit is handled with per-email rate limiting.
- **Sidekiq → Async adapter**: Removed Redis/Sidekiq dependency. Jobs run in-process with Rails' async adapter, which is sufficient at current scale and eliminates a paid add-on.
- **Subscriber-gated fetching**: The fetch job only queries sources with active subscribers (`NewsSource.joins(:users).where(is_subscribed: true)`), avoiding API calls to sources no one reads.
- **Memory-first design**: Every service class respects the 512MB ceiling with explicit thresholds, forced GC, and hard article caps.
