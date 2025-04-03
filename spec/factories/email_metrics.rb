FactoryBot.define do
    factory :email_metric do
      user
      email_type { 'daily_digest' }
      sent_at { Time.current }
      opened_at { nil }
      clicked_at { nil }
      status { 'sent' }
    end
  end