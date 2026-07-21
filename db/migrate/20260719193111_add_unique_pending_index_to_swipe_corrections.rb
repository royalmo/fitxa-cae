class AddUniquePendingIndexToSwipeCorrections < ActiveRecord::Migration[8.1]
  def change
    add_index :swipe_corrections,
      [ :employee_id, :day ],
      unique: true,
      where: "status = 'pending'",
      name: "index_swipe_corrections_on_employee_day_pending"
  end
end
