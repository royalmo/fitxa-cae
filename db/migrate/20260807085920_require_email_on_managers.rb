class RequireEmailOnManagers < ActiveRecord::Migration[8.1]
  def up
    change_column_null :managers, :email, false
    add_index :managers, "LOWER(email)", unique: true, name: "index_managers_on_lower_email"
  end

  def down
    remove_index :managers, name: "index_managers_on_lower_email"
    change_column_null :managers, :email, true
  end
end
