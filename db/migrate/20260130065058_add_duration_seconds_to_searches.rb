class AddDurationSecondsToSearches < ActiveRecord::Migration[8.0]
  def change
    add_column :searches, :duration_seconds, :integer
  end
end
