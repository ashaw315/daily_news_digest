class ApplicationMailer < ActionMailer::Base
  default from: "news@dailynewsdigest.com"
  layout "mailer"
  
  # Include the MailerHelper
  helper :mailer
end
