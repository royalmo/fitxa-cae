class CreateEmployeeBulkActionRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :employee_bulk_action_runs do |t|
      t.references :manager, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :status, null: false, default: "queued"
      t.integer :progress, null: false, default: 0
      t.text :result_message
      t.text :error_message
      t.datetime :completed_at
      t.datetime :failed_at
      t.json :parameters, null: false, default: {}

      t.timestamps
    end

    add_index :employee_bulk_action_runs, :status
    add_index :employee_bulk_action_runs, :kind
  end
end
