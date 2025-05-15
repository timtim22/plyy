class Resume < ApplicationRecord
  belongs_to :user
  has_many :searches, dependent: :destroy
  
  validates :filename, presence: true
end 