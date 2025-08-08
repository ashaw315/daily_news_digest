class ApplicationMailer < ActionMailer::Base
  # IMPORTANT: EMAIL_FROM_ADDRESS must match GMAIL_USERNAME when using Gmail SMTP
  default from: ENV['EMAIL_FROM_ADDRESS'] || "ashaw315@gmail.com"
  layout "mailer"
  
  # Include the MailerHelper
  helper :mailer
end
