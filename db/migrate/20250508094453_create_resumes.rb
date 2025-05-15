class CreateResumes < ActiveRecord::Migration[8.0]
  def change
    create_table :resumes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :filename
      t.text :parsed_text

      t.timestamps
    end
  end
end
