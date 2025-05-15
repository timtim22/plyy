class AddDescriptionToSearchResults < ActiveRecord::Migration[8.0]
  def change
    add_column :search_results, :description, :text
  end
end
