FactoryBot.define do
  factory :email_metric do
    association :user
    email_type { "daily_digest" }
    status { "sent" }  # Changed from "delivered" to "sent" to match model validation
    subject { "News Digest for #{Date.today.strftime('%B %d, %Y')}" }
    sent_at { Time.current }
    
    trait :sent do
      status { "sent" }
    end
    
    trait :opened do
      status { "opened" }
    end
    
    trait :clicked do
      status { "clicked" }
    end
    
    trait :failed do
      status { "failed" }
    end
  end
end