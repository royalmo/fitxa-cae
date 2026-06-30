class CreateJoinTableEmployeesTags < ActiveRecord::Migration[8.1]
  def change
    create_join_table :employees, :tags do |t|
      t.index [ :employee_id, :tag_id ], unique: true
      t.index [ :tag_id, :employee_id ]
    end
  end
end
