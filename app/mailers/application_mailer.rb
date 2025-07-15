class ApplicationMailer < ActionMailer::Base
  default from: ENV['EMAIL_FROM_ADDRESS'] || "ashaw315@gmail.com"  # Use verified SendGrid sender email
  layout "mailer"
  
  # Include the MailerHelper
  helper :mailer
end
