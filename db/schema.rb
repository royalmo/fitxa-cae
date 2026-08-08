# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_08_174216) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "audit_actions", force: :cascade do |t|
    t.integer "author_id", null: false
    t.string "author_type", null: false
    t.datetime "created_at", null: false
    t.json "extra_info"
    t.string "kind", null: false
    t.integer "recipient_id", null: false
    t.string "recipient_type", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_audit_actions_on_author"
    t.index ["recipient_type", "recipient_id"], name: "index_audit_actions_on_recipient"
  end

  create_table "daily_statistics", force: :cascade do |t|
    t.integer "active_user_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "pending_correction_count", default: 0, null: false
    t.integer "people_worked", default: 0, null: false
    t.date "snapshot_at", null: false
    t.datetime "updated_at", null: false
    t.index ["snapshot_at"], name: "index_daily_statistics_on_snapshot_at", unique: true
  end

  create_table "employees", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "first_name", null: false
    t.string "last_name"
    t.string "national_id", null: false
    t.string "password_digest"
    t.string "phone"
    t.json "settings", default: {}, null: false
    t.datetime "updated_at", null: false
  end

  create_table "employees_tags", id: false, force: :cascade do |t|
    t.integer "employee_id", null: false
    t.integer "tag_id", null: false
    t.index ["employee_id", "tag_id"], name: "index_employees_tags_on_employee_id_and_tag_id", unique: true
    t.index ["tag_id", "employee_id"], name: "index_employees_tags_on_tag_id_and_employee_id"
  end

  create_table "employment_periods", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "employee_id", null: false
    t.datetime "ended_at"
    t.datetime "started_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "ended_at"], name: "index_employment_periods_on_employee_id_and_ended_at"
    t.index ["employee_id", "started_at"], name: "index_employment_periods_on_employee_id_and_started_at"
    t.index ["employee_id"], name: "index_employment_periods_on_employee_id"
    t.index ["employee_id"], name: "index_employment_periods_on_employee_open_period", unique: true, where: "ended_at IS NULL"
  end

  create_table "managers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.integer "employee_id"
    t.string "first_name"
    t.string "last_name"
    t.string "password_digest"
    t.json "settings", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index "LOWER(email)", name: "index_managers_on_lower_email", unique: true
    t.index ["employee_id"], name: "index_managers_on_employee_id", unique: true
  end

  create_table "report_exports", force: :cascade do |t|
    t.datetime "completed_at"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.datetime "expires_at"
    t.datetime "failed_at"
    t.string "filename"
    t.string "kind", null: false
    t.integer "manager_id", null: false
    t.json "parameters", default: {}, null: false
    t.integer "progress", default: 0, null: false
    t.string "status", default: "queued", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_report_exports_on_expires_at"
    t.index ["manager_id"], name: "index_report_exports_on_manager_id"
    t.index ["status"], name: "index_report_exports_on_status"
  end

  create_table "swipe_corrections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "day", null: false
    t.datetime "deleted_at"
    t.json "details"
    t.integer "employee_id", null: false
    t.text "requester_comments"
    t.integer "requester_id", null: false
    t.string "requester_type", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.text "validator_comments"
    t.integer "validator_id"
    t.index ["deleted_at"], name: "index_swipe_corrections_on_deleted_at"
    t.index ["employee_id", "day"], name: "index_swipe_corrections_on_employee_day_pending", unique: true, where: "status = 'pending' AND deleted_at IS NULL"
    t.index ["employee_id"], name: "index_swipe_corrections_on_employee_id"
    t.index ["requester_type", "requester_id"], name: "index_swipe_corrections_on_requester"
    t.index ["validator_id"], name: "index_swipe_corrections_on_validator_id"
  end

  create_table "swipes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "employee_id", null: false
    t.boolean "forged", default: false, null: false
    t.string "kind", null: false
    t.string "metadata"
    t.boolean "removed", default: false, null: false
    t.datetime "swipe_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_swipes_on_employee_id"
  end

  create_table "tags", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.string "color", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index "LOWER(name)", name: "index_tags_on_lower_name", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "employment_periods", "employees"
  add_foreign_key "managers", "employees"
  add_foreign_key "report_exports", "managers"
  add_foreign_key "swipe_corrections", "employees"
  add_foreign_key "swipe_corrections", "managers", column: "validator_id"
  add_foreign_key "swipes", "employees"
end
