class CreateJobTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :job_types do |t|
      t.string :name

      t.timestamps
    end
    add_index :job_types, :name
  end
end
