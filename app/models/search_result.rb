class SearchResult < ApplicationRecord
  belongs_to :search
  
  validates :title, presence: true
end 