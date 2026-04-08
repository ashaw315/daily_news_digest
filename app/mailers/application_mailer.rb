class ApplicationMailer < ActionMailer::Base
  default from: ENV['EMAIL_FROM_ADDRESS'] || "onboarding@resend.dev"
  layout "mailer"

  helper :mailer
end
