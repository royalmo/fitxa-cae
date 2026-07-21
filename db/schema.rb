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

ActiveRecord::Schema[8.1].define(version: 2026_07_19_193111) do
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

  create_table "managers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.integer "employee_id"
    t.string "first_name"
    t.string "last_name"
    t.string "password_digest"
    t.json "settings", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_managers_on_employee_id", unique: true
  end

  create_table "swipe_corrections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "day", null: false
    t.json "details"
    t.integer "employee_id", null: false
    t.text "requester_comments"
    t.integer "requester_id", null: false
    t.string "requester_type", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.text "validator_comments"
    t.integer "validator_id"
    t.index ["employee_id", "day"], name: "index_swipe_corrections_on_employee_day_pending", unique: true, where: "status = 'pending'"
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
  end

  add_foreign_key "managers", "employees"
  add_foreign_key "swipe_corrections", "employees"
  add_foreign_key "swipe_corrections", "managers", column: "validator_id"
  add_foreign_key "swipes", "employees"
end
