class EmailMetric < ApplicationRecord
  belongs_to :user
  
  validates :status, presence: true, inclusion: { in: ['sent', 'opened', 'clicked', 'failed'] }
  
  scope :sent, -> { where(status: 'sent') }
  scope :opened, -> { where(status: 'opened') }
  scope :clicked, -> { where(status: 'clicked') }
  scope :failed, -> { where(status: 'failed') }
end 