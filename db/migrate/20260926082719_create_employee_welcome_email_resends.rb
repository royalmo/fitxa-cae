class CreateEmployeeWelcomeEmailResends < ActiveRecord::Migration[8.1]
  def change
    create_table :employee_welcome_email_resends do |t|
      t.references :manager, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.string :email, null: false
      t.string :status, default: "queued", null: false
      t.integer :progress, default: 0, null: false
      t.text :result_message
      t.text :error_message
      t.datetime :completed_at
      t.datetime :failed_at

      t.timestamps
    end

    add_index :employee_welcome_email_resends, :status
  end
end
