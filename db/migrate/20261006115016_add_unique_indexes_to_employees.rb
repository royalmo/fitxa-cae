class AddUniqueIndexesToEmployees < ActiveRecord::Migration[8.1]
  def change
    add_index :employees,
      "LOWER(national_id)",
      unique: true,
      name: "index_employees_on_lower_national_id"
    add_index :employees,
      "LOWER(email)",
      unique: true,
      where: "email IS NOT NULL",
      name: "index_employees_on_lower_email"
  end
end
