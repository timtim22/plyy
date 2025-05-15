class JobType < ApplicationRecord
  has_and_belongs_to_many :searches
  
  validates :name, presence: true, uniqueness: true
end 