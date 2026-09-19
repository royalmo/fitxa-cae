class AddAllowCorrectionsToEmployees < ActiveRecord::Migration[8.1]
  def change
    add_column :employees, :allow_corrections, :boolean, null: false, default: false
  end
end
