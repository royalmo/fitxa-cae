class CreateManagers < ActiveRecord::Migration[8.1]
  def change
    create_table :managers do |t|
      t.string :first_name
      t.string :last_name
      t.string :email
      t.boolean :active, null: false, default: true
      t.references :employee, null: true, foreign_key: true, index: { unique: true }
      t.json :settings, null: false, default: {}

      t.timestamps
    end
  end
end
