class ApplicationMailer < ActionMailer::Base
  default from: "from@example.com"
  layout "mailer"
  
  # Include the MailerHelper
  helper :mailer
end
