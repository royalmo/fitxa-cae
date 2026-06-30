class AddEmployeeToSwipeCorrections < ActiveRecord::Migration[8.1]
  def change
    add_reference :swipe_corrections, :employee, null: false, foreign_key: true
  end
end
