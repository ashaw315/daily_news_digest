require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    subject { build(:user) }  # Use build instead of create
    
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_presence_of(:preferences) }
  end

  describe 'associations' do
    it { should have_one(:email_tracking).dependent(:destroy) }
  end

  describe 'preferences' do
    let(:user) { create(:user) }

    it 'only allows valid preference keys' do
      user.preferences = { 
        'topics' => ['tech', 'science'],
        'sources' => ['news_api'],
        'frequency' => 'daily',
        'invalid_key' => 'value'
      }
      
      expect(user.preferences).not_to have_key('invalid_key')
      expect(user.preferences).to have_key('topics')
      expect(user.preferences).to have_key('sources')
      expect(user.preferences).to have_key('frequency')
    end

    it 'handles nil preferences' do
      user.preferences = nil
      expect(user.preferences).to eq({})
    end
  end
end
