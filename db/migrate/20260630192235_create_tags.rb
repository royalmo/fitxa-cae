class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: false
      t.string :color, null: false

      t.timestamps
    end
  end
end
