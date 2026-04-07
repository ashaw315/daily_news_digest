require 'rails_helper'

RSpec.describe User, 'create_default_preferences resilience', type: :model do
  before do
    # Ensure no Topics or NewsSources exist
    UserTopic.delete_all
    UserNewsSource.delete_all
    Preferences.delete_all
    Article.delete_all
    NewsSource.delete_all
    Topic.delete_all
  end

  it 'creates the user without raising when no Topics exist' do
    expect { create(:user) }.not_to raise_error
  end

  it 'creates the user without raising when no NewsSources exist' do
    expect { create(:user) }.not_to raise_error
  end

  it 'persists the user even with an empty database' do
    user = create(:user)

    expect(user).to be_persisted
    expect(user.reload).to eq(user)
  end

  it 'creates no topic or news source associations' do
    user = create(:user)

    expect(user.user_topics.count).to eq(0)
    expect(user.user_news_sources.count).to eq(0)
  end

  it 'still creates a preferences record' do
    user = create(:user)

    expect(user.preferences).to be_present
    expect(user.preferences.email_frequency).to eq('daily')
  end
end
