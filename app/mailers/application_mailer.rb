class ApplicationMailer < ActionMailer::Base
  default from: "ashaw315@gmail.com"  # Use your verified SendGrid sender email
  layout "mailer"
  
  # Include the MailerHelper
  helper :mailer
end
