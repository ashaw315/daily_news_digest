class Topic < ApplicationRecord
    validates :name, presence: true, uniqueness: true
    
    has_many :user_topics
    has_many :users, through: :user_topics
    
    scope :active, -> { where(active: true) }
  end