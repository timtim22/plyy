class Search < ApplicationRecord
  belongs_to :user
  belongs_to :resume
  has_many :search_results, dependent: :destroy
  
  has_and_belongs_to_many :categories
  has_and_belongs_to_many :job_types
  has_and_belongs_to_many :locations
end 