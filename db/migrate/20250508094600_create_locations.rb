class CreateLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :locations do |t|
      t.string :name

      t.timestamps
    end
    add_index :locations, :name
  end
end
