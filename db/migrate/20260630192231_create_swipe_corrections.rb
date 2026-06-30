class CreateSwipeCorrections < ActiveRecord::Migration[8.1]
  def change
    create_table :swipe_corrections do |t|
      t.references :requester, polymorphic: true, null: false
      t.references :validator, null: true, foreign_key: { to_table: :managers }
      t.string :status, null: false, default: "pending"
      t.json :details
      t.text :requester_comments
      t.text :validator_comments
      t.date :day, null: false

      t.timestamps
    end
  end
end
