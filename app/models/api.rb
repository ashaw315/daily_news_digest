class Api < ApplicationRecord
    validates :name, presence: true, uniqueness: true
    validates :endpoint, presence: true
    validates :priority, presence: true, 
              numericality: { only_integer: true, greater_than_or_equal_to: 0 }
              
    scope :by_priority, -> { order(priority: :desc) }
end
