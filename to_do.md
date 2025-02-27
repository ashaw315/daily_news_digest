# AI-Powered News Aggregator TODO List
## General Setup
- [ ] Set up a new Rails project.
- [ ] Add necessary gems:
 - [ ] `devise` for user authentication.
 - [ ] `sidekiq` for background jobs.
 - [ ] `pg` for PostgreSQL.
 - [ ] `dotenv-rails` for environment variables.
 - [ ] `faraday` or `httparty` for API requests.
 - [ ] `mailgun-ruby` or `sendgrid` for email handling.
 - [ ] `active_job` for background tasks (integrates with
Sidekiq).
- [ ] Set up Git repository and basic branches (`main`, `dev`).
---
## 1. User Authentication
### Devise Setup
- [ ] Install and configure `devise`.
- [ ] Set up User model with:
 - [ ] Email.
 - [ ] Password (with validation and encryption).
 - [ ] Email confirmation (via `devise`).
 - [ ] Password reset functionality.
- [ ] Implement user registration and sign-in views.
- [ ] Test user sign-up, login, and password reset.
---
## 2. User Preferences & Email Management
### User Preferences Schema
- [ ] Add `preferences` column to the User table (JSON type).
- [ ] Add `is_subscribed` boolean to User (default true).
- [ ] Implement logic to allow users to:
 - [ ] Select topics of interest (e.g., Technology, Sports,
etc.).
 - [ ] Choose their preferred news sources (via API).
 - [ ] Reset preferences to default.
### Unsubscribe Functionality
- [ ] Implement unsubscribe link in the email footer.
- [ ] Set up a route and controller for unsubscribe action.
- [ ] Remove user from email list upon unsubscription.
- [ ] Ensure unsubscribed users don’t receive further emails.
---
## 3. Content Sources & API Integration
### News API Integration
- [ ] Select and integrate multiple news APIs:
 - [ ] NewsAPI.
 - [ ] New York Times API.
 - [ ] Any other free API.
- [ ] Create a model for `API` (stores metadata for APIs).
 - [ ] Fields: `name`, `endpoint`, `priority`.
- [ ] Implement API fetching logic:
 - [ ] Create a service class to fetch news from APIs.
 - [ ] Ensure fallback API fetching mechanism (e.g., fallback
to next API if one fails).
- [ ] Implement topic categorization (using keyword extraction
or ML).
- [ ] Test API fetching and handling of articles.
---
## 4. Email Content Structure
### Email Generation
- [ ] Set up background job to send daily emails.
- [ ] Create an EmailService to generate and send emails.
 - [ ] Subject: “Your Daily News Digest for [Date]”.
 - [ ] Greeting: "Good morning [Name], here’s your daily news
update!"
 - [ ] Sections:
 - [ ] Trending Topics: List with summaries and links.
 - [ ] Top 10 Articles Grouped by Topic: List of articles
with titles, summaries, sources, and dates.
 - [ ] News of the Day Brief: 10-15 summaries from userselected API.
 - [ ] Footer with unsubscribe link.
- [ ] Ensure articles are properly categorized and linked.
- [ ] Add HTML structure and formatting.
 - [ ] Basic HTML layout with sections clearly separated.
 - [ ] Use icons next to topics (e.g., basketball for sports).
### Email Delivery
- [ ] Set up an email service (Mailgun, SendGrid).
- [ ] Configure environment variables for API keys.
- [ ] Implement background job to send emails at 8 AM daily.
- [ ] Ensure email delivery works in staging (use Mailtrap).
- [ ] Implement retry mechanism for email delivery failures.
 - [ ] Retry 1 hour after failure.
 - [ ] Remove user after 3 failed attempts.
---
## 5. Admin Interface
### Admin Setup
- [ ] Set up an admin interface using Devise.
- [ ] Restrict access to admin routes with a custom
authorization (only platform owner).
- [ ] Implement CRUD functionality for:
 - [ ] Managing news APIs (add/remove).
 - [ ] Managing user preferences.
 - [ ] Viewing email delivery and user metrics (opens, clicks,
etc.).
- [ ] Set up views for admin dashboard.
- [ ] Test admin authentication and access control.
---
## 6. Analytics & Tracking
### Metrics Tracking
- [ ] Implement tracking for email opens and clicks.
 - [ ] Use Rails background jobs to collect and store email 
engagement metrics.
 - [ ] Store data in an `EmailTracking` model.
 - [ ] Include user ID, open count, click count.
- [ ] Set up metrics email for admin (sent weekly with open/
click data).
- [ ] Test tracking of email interactions (open and click
rates).
---
## 7. Error Handling & Retry Strategy
### Email Failure Handling
- [ ] Implement email failure handling in background job:
 - [ ] Retry email after 1 hour.
 - [ ] Remove user from database after 3 failed attempts.
 - [ ] Log all email delivery errors.
 - [ ] Set up email alerts for recurring email delivery
issues.
- [ ] Test failure scenarios (simulate failed emails).
---
## 8. Database Setup
### Database Schema
- [ ] Set up PostgreSQL database and configure `database.yml`.
- [ ] Create models:
 - [ ] User:
 - [ ] `preferences` (JSON).
 - [ ] `is_subscribed` (boolean).
 - [ ] Article:
 - [ ] `title`, `summary`, `url`, `publish_date`, `source`,
`topic`.
 - [ ] API:
 - [ ] `name`, `endpoint`, `priority`.
 - [ ] EmailTracking:
 - [ ] `user_id`, `open_count`, `click_count`.
- [ ] Run database migrations.
- [ ] Test database setup (create, read, update, delete
operations).
---
## 9. Testing
### Unit & Integration Tests
- [ ] Write unit tests for:
 - [ ] User authentication (sign-up, login, password reset).
 - [ ] User preference management.
 - [ ] News API integration (fetching, fallback,
categorization).
 - [ ] Email content generation (check formatting and
sections).
 - [ ] Admin interface (access control, CRUD operations).
- [ ] Write integration tests for:
 - [ ] Full email delivery workflow (from background job to
user inbox).
 - [ ] Email failure handling and retries.
 - [ ] Admin dashboard functionality.
- [ ] Write functional tests for unsubscribe functionality.
---
## 10. Deployment & Scaling
### Deployment Setup
- [ ] Set up production environment on Heroku (or preferred
host).
- [ ] Configure email service for production (Mailgun/
SendGrid).
- [ ] Set up Sidekiq for background jobs.
- [ ] Configure PostgreSQL production database.
- [ ] Set up environment variables for production (API keys,
email services).
- [ ] Deploy the app to production.
### Scaling Considerations
- [ ] Ensure email delivery system is scalable (use Sidekiq
with Redis).
- [ ] Set up monitoring and alerting for email delivery.
- [ ] Use Redis caching for news articles to reduce API calls.
---
## 11. Post-Launch Monitoring
- [ ] Set up error tracking (Sentry, Bugsnag).
- [ ] Monitor email delivery and engagement metrics (open
rates, click rates).
- [ ] Monitor system performance and fix any scaling issues.