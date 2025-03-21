Prompt 1: Project Initialization & Setup
Task:
- Create a new Rails application using PostgreSQL.
- Configure the project for test-driven development (using
RSpec, for example).
- Add required gems to the Gemfile: devise, sidekiq (for
background jobs), and any testing gems (rspec-rails,
factory_bot, etc.).
- Initialize Git and commit the initial project structure.
Instructions:
1. Generate a new Rails app with PostgreSQL.
2. Add Devise and Sidekiq gems (and any testing libraries).
3. Configure the application for RSpec.
4. Set up initial configurations (e.g., database.yml) and
commit your changes.
5. Write a basic "smoke test" that confirms the app boots up
and the database is connected.
Your output should include:
- The updated Gemfile.
- Commands to generate the app and install gems.
- A simple RSpec test confirming the Rails environment is set
up.

Prompt 2: Implementing User Authentication with Devise
Task:
- Integrate Devise for user authentication.
- Generate the User model using Devise.
- Configure email confirmation and password reset.
- Write tests (unit/integration) to ensure sign-up, login,
email confirmation, and password reset work as expected.
Instructions:
1. Run the Devise generator to set up the User model.
2. Configure Devise for email confirmation.
3. Create basic views for sign-up, login, and password reset.
4. Write RSpec tests that simulate user registration (including
email confirmation) and password recovery.
5. Commit all code and tests.
 Your output should include:
- The commands used to generate Devise files.
- The configuration changes in config/initializers/devise.rb
(if any).
- Sample RSpec tests for sign-up, login, and password reset.

Prompt 3: Defining the Database Schema
Task:
- Create migrations and models for:
  - User (with preferences stored as JSON and an is_subscribed
boolean).
  - Article (with fields: title, summary, url, publish_date,
source, topic).
  - API (with fields: name, endpoint, priority).
  - (Optional) EmailTracking (with fields: user_id, open_count,
click_count).
- Use best practices to create associations (if needed) and
validations.
- Write model tests (using RSpec) to confirm that migrations
have created the proper schema and validations are in place.
Instructions:
1. Generate models and migrations for User, Article, API, and
EmailTracking.
2. Ensure the User model has a JSON field for preferences and a
boolean for subscription status.
3. Write tests to check that records can be created with the
expected fields.

4. Commit the migrations, models, and tests.
Your output should include:
- The migration files.
- The model files with validations.
- RSpec tests verifying the schema.

Prompt 4: Implementing User Preferences Management
Task:
- Build a user settings page that allows users to select topics
of interest and choose their preferred news source.
- The form should update the User model’s preferences (stored
as JSON).

 - Provide a “Reset Preferences” option that clears the current
selections and presents a clean slate.
- Write tests to ensure the preferences update and reset
functionalities work correctly.
Instructions:
1. Create a controller (e.g., PreferencesController) and
corresponding views for managing preferences.
2. In the User model, add helper methods to read and update
preferences.
3. Implement a form that lets users check/uncheck topics and
choose a news source.
4. Add a “Reset Preferences” button that, when clicked, clears
the user’s saved preferences.
5. Write integration tests that simulate updating and resetting
preferences.
6. Wire the “Manage Preferences” link in a layout so it’s
accessible from emails.
7. Commit all changes and tests.
Your output should include:
- The controller and view code.
- The User model changes for handling JSON preferences.
- RSpec tests for updating and resetting preferences.

Prompt 5: Email Content Generation – Building the Mailer
Task:
- Create a Mailer (e.g., DailyNewsMailer) that composes the
daily email.
- The email should include:
  - A personalized greeting.
  - A “News of the Day Brief” section (with 10–15 bullet-point
summaries from the user-selected API).
- A “Trending Topics” section with predefined icons (e.g., for Technology, for Sports).
  - A “Top 10 Articles of the Day” grouped by topic, with
title, summary, source, publish date, and a “Read More” link.
  - A footer with an unsubscribe link and a link to manage
preferences.
- Wire the mailer to use an HTML template.
- Write tests (using ActionMailer’s test helpers) to ensure the
email content is correctly generated and formatted.
  
 Instructions:
1. Generate the mailer using Rails generator.
2. Create the email view templates (HTML and plain text if
needed).
3. In the mailer method, build dynamic content based on the
user’s preferences and the articles fetched.
4. Write tests to confirm that the generated email includes the
correct sections and links.
5. Commit your mailer code and tests.
Your output should include:
- The mailer class and its method(s).
- The HTML template for the email.
- Sample tests verifying email content (subject, greeting,
sections, unsubscribe link).

Prompt 6: Implementing Email Scheduling and Delivery
Task:
- Schedule the DailyNewsMailer to send emails at 8 AM every
day.
- Use a background job (via Sidekiq or ActiveJob) to handle
email delivery.
- Incorporate a retry mechanism:
  - If an email fails, retry after 1 hour.
  - After three failed attempts, purge the user from the
database.
- Write tests to simulate email delivery, retries, and user
purging after repeated failures.
Instructions:
1. Create a job (e.g., DailyEmailJob) that calls the mailer.
2. Configure the job to be enqueued at 8 AM daily (using a
scheduler like the whenever gem or Rails cron).
3. Implement retry logic in the job (or within a custom
wrapper) to wait 1 hour between retries and count failures.
4. Integrate error logging using Rails Logger.
5. Write tests to simulate failure scenarios and verify that
after three attempts the user record is removed.
6. Commit your job code and tests.
Your output should include:

 - The job class with scheduling and retry logic.
- Configuration files for scheduling (if applicable).
- RSpec tests simulating email failure and verifying purging
logic.

Prompt 7: Integrating News API Management & Article
Categorization
Task:
- Implement logic to fetch articles from multiple news APIs.
- Build a module/service that:
  - Rotates between APIs based on reliability, speed, and
quality.
  - Falls back to secondary APIs if the primary fails.
  - Allows the user to select their preferred API for the “News
of the Day Brief.”
- Integrate automatic topic categorization using keyword
extraction (you can use a simple gem or built-in methods).
- Store fetched articles in the Article table.
- Write tests to simulate fetching, categorization, and storage
of articles.
Instructions:
1. Create a service class (e.g., NewsFetcher) that interacts
with multiple APIs.
2. In the service, implement a mechanism to choose an API based
on a priority system.
3. Write methods to fetch articles, parse the results, and
perform basic keyword extraction for topic detection.
4. Save the articles to the database.
5. Write tests for each method in the service.
6. Commit your service code and tests.
Your output should include:
- The service class for fetching and processing articles.
- Code snippets showing how topic categorization is performed.
- RSpec tests covering API selection, article fetching, and
categorization.

Prompt 8: Building the Admin Interface
Task:
- Create an admin dashboard accessible only to you (the single
admin user).

 - The interface should allow:
  - Managing content sources (add, remove, update APIs).
  - Viewing user preferences.
  - Viewing email metrics (opens, clicks, failures).
- Use the same Devise authentication for admin access.
- Write tests to verify that only an authenticated admin can
access the interface and perform management actions.
Instructions:
1. Create an Admin namespace with controllers and views (e.g.,
Admin::DashboardController, Admin::ApisController).
2. Implement authentication filters to restrict access to admin
routes.
3. Build simple forms for managing APIs and viewing metrics.
4. Write integration tests that ensure unauthorized users
cannot access the admin interface.
5. Commit your admin interface code and tests.
Your output should include:
- Controller, view, and routing code for the admin interface.
- Sample tests verifying access control and functionality.

Prompt 9: End-to-End Integration & Final Testing
Task:
- Wire together all previously built components into a cohesive
system.
- Create an end-to-end test that covers:
  - User registration, email confirmation, and preference
setup.
  - Article fetching, categorization, and storage.
  - Generation and scheduled delivery of the daily email.
  - Retry mechanism and purging of undeliverable emails.
  - Access and management via the admin interface.
- Ensure that no code is orphaned and that every piece is
properly integrated.
- Run the full test suite and document any final integration
details.
Instructions:
1. Write a comprehensive integration test (or a set of tests)
that simulates the entire flow.
2. Confirm that the daily email is generated with the correct
content based on user preferences.

3. Simulate email delivery failures and verify the retry and
purge mechanisms.
4. Validate that the admin interface reflects current API
configurations, user preferences, and email metrics.
5. Commit all integration tests and ensure the build passes.
Your output should include:
- The integration test(s) code.
- Any wiring/configuration changes needed to tie all components
together.
- A summary of how to run the full test suite.
