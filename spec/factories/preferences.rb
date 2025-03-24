FactoryBot.define do
    factory :preferences do
      association :user
      topics { [] }
      sources { [] }
      email_frequency { 'daily' }
      dark_mode { false }
    end
  end