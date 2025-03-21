class EmailTracking < ApplicationRecord
  belongs_to :user
  
  validates :open_count, presence: true, 
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :click_count, presence: true, 
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
