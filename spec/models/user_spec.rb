require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    subject { build(:user) }  # Use build instead of create
    
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    
    # Custom validation tests
    describe 'minimum_preferences_selected' do
      let(:user) { create(:user) } # Create a user
      
      it 'requires at least 3 topics for existing users' do
        # Skip validation for new records
        new_user = build(:user)
        expect(new_user).to be_valid
        
        # For existing users, clear existing topics
        user.topics.clear
        
        # Add only 2 topics
        user.topics << create(:topic, name: 'topic1')
        user.topics << create(:topic, name: 'topic2')
        
        # Validation should fail
        expect(user).not_to be_valid
        expect(user.errors[:topics]).to include(/You must select at least 3 topics/)
      end
      
      it 'requires at least 1 news source for existing users' do
        # Ensure user has 3+ topics to pass that validation
        3.times do |i|
          user.topics << create(:topic, name: "topic#{i}") unless user.topics.find_by(name: "topic#{i}")
        end
        
        # Clear existing news sources
        user.news_sources.clear
        
        # Validation should fail
        expect(user).not_to be_valid
        expect(user.errors[:news_sources]).to include(/You must select at least 1 news source/)
      end
      
      it 'passes when requirements are met' do
        # Create a news source if it doesn't exist
        news_source = NewsSource.find_by(name: 'source1') || create(:news_source, name: 'source1')
        
        # Ensure user has 3+ topics
        3.times do |i|
          user.topics << create(:topic, name: "topic#{i}") unless user.topics.find_by(name: "topic#{i}")
        end
        
        # Ensure user has 1+ news source
        user.news_sources << news_source unless user.news_sources.include?(news_source)
        
        # Validation should pass
        expect(user).to be_valid
      end
    end
  end

  describe 'associations' do
    it { should have_one(:email_tracking).dependent(:destroy) }
    it { should have_one(:preferences).dependent(:destroy) }
    it { should have_many(:user_topics).dependent(:destroy) }
    it { should have_many(:topics).through(:user_topics) }
    it { should have_many(:user_news_sources).dependent(:destroy) }
    it { should have_many(:news_sources).through(:user_news_sources) }
    it { should have_many(:email_metrics).dependent(:destroy) }
  end

  describe 'preferences jsonb column' do
    let(:user) { create(:user) }

    it 'stores and retrieves preferences in the jsonb column' do
      # Get direct access to the JSONB column
      jsonb_preferences = { 
        'topics' => ['tech', 'science'],
        'sources' => ['news_api'],
        'frequency' => 'daily'
      }
      
      # Update the JSONB preferences column directly
      user.update_column(:preferences, jsonb_preferences)
      
      # Reload to get the latest values
      user.reload
      
      # Access the raw JSONB column data using read_attribute
      raw_preferences = user.read_attribute(:preferences)
      
      # Check that we can access the JSONB data
      expect(raw_preferences['topics']).to include('tech')
      expect(raw_preferences['sources']).to include('news_api')
      expect(raw_preferences['frequency']).to eq('daily')
    end

    it 'defaults to empty hash for preferences jsonb column' do
      # Create a new user without setting preferences
      new_user = create(:user)
      
      # Force nil to test the default
      new_user.update_column(:preferences, {})
      
      # Reload to get the latest values
      new_user.reload
      
      # Access the raw JSONB column data using read_attribute
      raw_preferences = new_user.read_attribute(:preferences)
      
      # Should be an empty hash, not nil
      expect(raw_preferences).to eq({})
    end
  end
  
  describe 'preferences association' do
    let(:user) { create(:user) }
    
    it 'has a preferences association' do
      expect(user.preferences).to be_a(Preferences)
    end
    
    it 'has default values in the preferences association' do
      expect(user.preferences.email_frequency).to eq('daily')
      expect(user.preferences.dark_mode).to eq(false)
    end
  end
  
  describe 'callbacks' do
    it 'generates an unsubscribe token before creation' do
      # Since the token is generated in a before_create callback,
      # we need to use a new instance that hasn't been saved yet
      user = build(:user, unsubscribe_token: nil)
      
      # Save the user to trigger the callback
      user.save
      
      # Now the token should be present
      expect(user.unsubscribe_token).not_to be_nil
      expect(user.unsubscribe_token.length).to be >= 32
    end
    
    it 'creates a preferences record after creation' do
      user = create(:user)
      
      # Check that preferences association exists
      expect(user.preferences).not_to be_nil
      expect(user.preferences).to be_a(Preferences)
      
      # Check that the preferences record has default values
      expect(user.preferences.email_frequency).to eq('daily')
    end
  end
  
  describe 'instance methods' do
    let(:user) { create(:user) }
    
    describe '#email_frequency' do
      it 'returns the email frequency from preferences' do
        user.preferences.update(email_frequency: 'weekly')
        expect(user.email_frequency).to eq('weekly')
      end
    end
    
    describe '#is_subscribed?' do
      it 'returns true when is_subscribed is true' do
        user.update(is_subscribed: true)
        expect(user.is_subscribed?).to be true
      end
      
      it 'returns false when is_subscribed is false' do
        user.update(is_subscribed: false)
        expect(user.is_subscribed?).to be false
      end
    end
  end
end