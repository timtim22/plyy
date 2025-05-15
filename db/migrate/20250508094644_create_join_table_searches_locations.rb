class CreateJoinTableSearchesLocations < ActiveRecord::Migration[8.0]
  def change
    create_join_table :searches, :locations do |t|
      t.index [:search_id, :location_id]
      t.index [:location_id, :search_id]
    end
  end
end
