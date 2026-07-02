class AddPasswordDigestToEmployees < ActiveRecord::Migration[8.1]
  def change
    add_column :employees, :password_digest, :string
  end
end
