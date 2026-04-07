require 'rails_helper'

RSpec.describe User, 'signup without email confirmation', type: :model do
  it 'creates a user that is persisted and immediately active' do
    user = create(:user)

    expect(user).to be_persisted
    expect(user.active_for_authentication?).to be true
  end

  it 'does not include :confirmable in Devise modules' do
    expect(User.devise_modules).not_to include(:confirmable)
  end

  it 'is accessible without a confirmation step' do
    user = create(:user, confirmed_at: nil)

    expect(user).to be_persisted
    expect(user.active_for_authentication?).to be true
  end
end
