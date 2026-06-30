class CreateSwipes < ActiveRecord::Migration[8.1]
  def change
    create_table :swipes do |t|
      t.references :employee, null: false, foreign_key: true
      t.datetime :swipe_at, null: false
      t.string :kind, null: false
      t.boolean :removed, null: false, default: false
      t.string :metadata
      t.boolean :forged, null: false, default: false

      t.timestamps
    end
  end
end
