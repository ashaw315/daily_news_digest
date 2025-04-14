class Topic < ApplicationRecord
    validates :name, presence: true, uniqueness: true
    
    has_many :user_topics, dependent: :nullify
    has_many :users, through: :user_topics
    
    scope :active, -> { where(active: true) }
    def in_use?
      user_topics.exists?
    end
  end