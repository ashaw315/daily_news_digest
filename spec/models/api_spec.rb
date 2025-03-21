require 'rails_helper'

RSpec.describe Api, type: :model do
  describe 'validations' do
    subject { create(:api) }
    
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
    it { should validate_presence_of(:endpoint) }
    it { should validate_presence_of(:priority) }
    it { should validate_numericality_of(:priority).is_greater_than_or_equal_to(0) }
  end

  describe 'scopes' do
    let!(:high_priority) { create(:api, priority: 2) }
    let!(:low_priority) { create(:api, priority: 1) }

    it 'orders by priority' do
      expect(Api.by_priority.first).to eq(high_priority)
    end
  end
end