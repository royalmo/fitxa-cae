class CreateReportExports < ActiveRecord::Migration[8.1]
  def change
    create_table :report_exports do |t|
      t.references :manager, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :status, null: false, default: "queued"
      t.integer :progress, null: false, default: 0
      t.string :filename
      t.string :content_type
      t.text :error_message
      t.datetime :expires_at
      t.datetime :completed_at
      t.datetime :failed_at
      t.json :parameters, null: false, default: {}

      t.timestamps
    end

    add_index :report_exports, :status
    add_index :report_exports, :expires_at
  end
end
