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

ActiveRecord::Schema[8.1].define(version: 2025_10_30_095000) do
  create_table "memberships", force: :cascade do |t|
    t.integer "coupon_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "features"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.integer "chat_coupons"
    t.datetime "created_at", null: false
    t.string "email"
    t.bigint "membership_id"
    t.string "password_digest"
    t.datetime "updated_at", null: false
    t.index ["membership_id"], name: "index_users_on_membership_id"
  end

  add_foreign_key "users", "memberships"
end
