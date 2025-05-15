class CreateJoinTableSearchesJobTypes < ActiveRecord::Migration[8.0]
  def change
    create_join_table :searches, :job_types do |t|
      t.index [:search_id, :job_type_id]
      t.index [:job_type_id, :search_id]
    end
  end
end
