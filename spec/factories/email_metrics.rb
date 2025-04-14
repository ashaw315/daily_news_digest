FactoryBot.define do
  factory :email_metric do
    association :user
    email_type { "daily_digest" }
    status { "delivered" }
    subject { "News Digest for #{Date.today.strftime('%B %d, %Y')}" }
    sent_at { Time.current }
  end
end