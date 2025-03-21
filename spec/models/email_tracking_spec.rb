require 'rails_helper'

RSpec.describe EmailTracking, type: :model do
  describe 'validations' do
    it { should belong_to(:user) }
    it { should validate_presence_of(:open_count) }
    it { should validate_presence_of(:click_count) }
    it { should validate_numericality_of(:open_count).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:click_count).is_greater_than_or_equal_to(0) }
  end
end