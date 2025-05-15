class CreateJoinTableSearchesCategories < ActiveRecord::Migration[8.0]
  def change
    create_join_table :searches, :categories do |t|
      t.index [:search_id, :category_id]
      t.index [:category_id, :search_id]
    end
  end
end
