class AddSavedToSearchResults < ActiveRecord::Migration[8.0]
  def change
    add_column :search_results, :saved, :boolean, default: false
  end
end
