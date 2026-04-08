FactoryBot.define do
  factory :email_tracking do
    user
    open_count { 0 }
    click_count { 0 }
    token { SecureRandom.urlsafe_base64(32) }
  end
end