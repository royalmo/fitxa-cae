class CreateAuditActions < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_actions do |t|
      t.references :author, polymorphic: true, null: false
      t.references :recipient, polymorphic: true, null: false
      t.string :kind, null: false
      t.json :extra_info

      t.timestamps
    end
  end
end
