class AddPasswordDigestToManagers < ActiveRecord::Migration[8.1]
  def change
    add_column :managers, :password_digest, :string
  end
end
