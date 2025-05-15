class AddDetailsToSearchResults < ActiveRecord::Migration[8.0]
  def change
    add_column :search_results, :salary, :string
    add_column :search_results, :work_setting, :string
    add_column :search_results, :reference_number, :string
  end
end
