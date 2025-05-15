class CreateSearchResults < ActiveRecord::Migration[8.0]
  def change
    create_table :search_results do |t|
      t.references :search, null: false, foreign_key: true
      t.string :title
      t.string :company
      t.string :location
      t.text :summary
      t.string :url

      t.timestamps
    end
  end
end
