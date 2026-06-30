class CreateEmployees < ActiveRecord::Migration[8.1]
  def change
    create_table :employees do |t|
      t.string :first_name, null: false
      t.string :last_name
      t.string :national_id, null: false
      t.string :phone
      t.string :email
      t.boolean :active, null: false, default: true
      t.json :settings, null: false, default: {}

      t.timestamps
    end
  end
end
