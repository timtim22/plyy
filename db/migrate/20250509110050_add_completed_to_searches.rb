class AddCompletedToSearches < ActiveRecord::Migration[8.0]
  def change
    add_column :searches, :completed, :boolean
  end
end
