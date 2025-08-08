# SendGrid to Gmail SMTP Migration Guide

## Overview
This guide documents the migration from SendGrid to Gmail SMTP for sending daily digest emails in production.

## Prerequisites

### 1. Create a Gmail App Password
Gmail requires an App Password for SMTP authentication instead of your regular password.

1. Go to your Google Account settings: https://myaccount.google.com/
2. Navigate to Security → 2-Step Verification (must be enabled)
3. Scroll down to "App passwords"
4. Generate a new app password for "Mail"
5. Copy the 16-character password (you won't be able to see it again)

### 2. Environment Variables
Set the following environment variables in production:

```bash
# Gmail SMTP Configuration
GMAIL_USERNAME=your_gmail@gmail.com         # Your Gmail address
GMAIL_APP_PASSWORD=your_16_char_app_pass    # App password from step 1
EMAIL_FROM_ADDRESS=your_gmail@gmail.com     # MUST match GMAIL_USERNAME

# Remove these SendGrid variables if present:
# SENDGRID_API_KEY (no longer needed)
```

## Gmail Sending Limits

### Important Limits to Consider:
- **Regular Gmail accounts**: 500 emails per day
- **Google Workspace accounts**: 2,000 emails per day
- **Rate limiting**: Maximum 20 messages per second

### Monitoring Usage
The application includes:
- 1-second delay between emails to prevent rate limiting
- Logging of total emails sent per day
- Error handling for rate limit exceptions

## Migration Steps

### 1. Update Environment Variables
```bash
# On your production server or deployment platform
export GMAIL_USERNAME="your_gmail@gmail.com"
export GMAIL_APP_PASSWORD="your_app_password_here"
export EMAIL_FROM_ADDRESS="your_gmail@gmail.com"

# Remove SendGrid variable
unset SENDGRID_API_KEY
```

### 2. Deploy the Updated Code
The following files have been updated:
- `config/environments/production.rb` - Gmail SMTP settings
- `app/mailers/application_mailer.rb` - From address documentation
- `app/jobs/daily_email_job.rb` - Rate limiting delay
- `lib/tasks/scheduler.rake` - Gmail limits documentation

### 3. Verify Configuration
After deployment, test the email configuration:

```bash
# SSH into production server
rails console

# Test email sending
TestMailer.test_email.deliver_now

# Or use the admin test suite
rails test_email:send_test
```

### 4. Monitor Initial Sends
Check logs for successful email delivery:

```bash
# View recent email logs
tail -f log/production.log | grep -E "DailyEmailJob|DailyNewsMailer"

# Check for Gmail-specific errors
tail -f log/production.log | grep -i "smtp\|gmail"
```

## Troubleshooting

### Common Issues

1. **Authentication Failed**
   - Ensure 2-Step Verification is enabled on the Gmail account
   - Verify the App Password is correct (16 characters, no spaces)
   - Check that EMAIL_FROM_ADDRESS matches GMAIL_USERNAME

2. **Rate Limit Errors**
   - The app includes a 1-second delay between emails
   - For more than 500 users, consider using Google Workspace
   - Or implement email batching across multiple days

3. **Emails Going to Spam**
   - Ensure SPF/DKIM records are set up for your domain
   - Use a consistent FROM address
   - Avoid spam trigger words in subject/content

### Gmail SMTP Error Codes
- `535` - Authentication failed (wrong username/password)
- `550` - User not found or mailbox unavailable
- `421` - Too many connections/rate limited
- `454` - Temporary authentication failure

## Rollback Plan
If issues arise, you can rollback to SendGrid:

1. Restore the SendGrid configuration in `config/environments/production.rb`
2. Set the `SENDGRID_API_KEY` environment variable
3. Deploy the reverted code

## Benefits of Gmail SMTP
- Better deliverability due to Google's reputation
- Built-in spam filtering
- No additional service costs
- Direct integration with Google Workspace (if applicable)

## Security Considerations
- App Passwords are as powerful as your main password - keep them secure
- Rotate App Passwords periodically
- Monitor account for unusual activity
- Enable Gmail's security alerts

## Future Considerations
If your user base grows beyond Gmail's limits:
1. Upgrade to Google Workspace for 2,000 emails/day
2. Implement email queuing/batching across multiple days
3. Consider enterprise email services (SendGrid, AWS SES, Mailgun)
4. Use multiple Gmail accounts with load balancing