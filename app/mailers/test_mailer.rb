class TestMailer < ApplicationMailer
    def test_email
      mail(to: 'ashaw315@gmail.com', subject: 'Test Email')
    end
  end