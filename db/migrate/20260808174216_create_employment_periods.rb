class CreateEmploymentPeriods < ActiveRecord::Migration[8.1]
  def change
    create_table :employment_periods do |t|
      t.references :employee, null: false, foreign_key: true
      t.datetime :started_at, null: false
      t.datetime :ended_at

      t.timestamps
    end

    add_index :employment_periods, [ :employee_id, :started_at ]
    add_index :employment_periods, [ :employee_id, :ended_at ]
    add_index :employment_periods,
      :employee_id,
      unique: true,
      where: "ended_at IS NULL",
      name: "index_employment_periods_on_employee_open_period"
  end
end
