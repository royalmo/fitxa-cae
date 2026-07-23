class AddDeletedAtToSwipeCorrections < ActiveRecord::Migration[8.1]
  def up
    add_column :swipe_corrections, :deleted_at, :datetime
    remove_index :swipe_corrections, name: "index_swipe_corrections_on_employee_day_pending"
    add_index :swipe_corrections,
      [ :employee_id, :day ],
      unique: true,
      where: "status = 'pending' AND deleted_at IS NULL",
      name: "index_swipe_corrections_on_employee_day_pending"
    add_index :swipe_corrections, :deleted_at
  end

  def down
    remove_index :swipe_corrections, column: :deleted_at
    remove_index :swipe_corrections, name: "index_swipe_corrections_on_employee_day_pending"
    add_index :swipe_corrections,
      [ :employee_id, :day ],
      unique: true,
      where: "status = 'pending'",
      name: "index_swipe_corrections_on_employee_day_pending"
    remove_column :swipe_corrections, :deleted_at
  end
end
