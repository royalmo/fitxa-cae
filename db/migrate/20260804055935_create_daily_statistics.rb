class CreateDailyStatistics < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_statistics do |t|
      t.date :snapshot_at, null: false
      t.integer :active_user_count, null: false, default: 0
      t.integer :pending_correction_count, null: false, default: 0
      t.integer :people_worked, null: false, default: 0

      t.timestamps
    end

    add_index :daily_statistics, :snapshot_at, unique: true
  end
end
