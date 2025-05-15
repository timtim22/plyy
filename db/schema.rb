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

ActiveRecord::Schema[8.0].define(version: 2025_05_09_181147) do
  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name"
  end

  create_table "categories_searches", id: false, force: :cascade do |t|
    t.integer "search_id", null: false
    t.integer "category_id", null: false
    t.index ["category_id", "search_id"], name: "index_categories_searches_on_category_id_and_search_id"
    t.index ["search_id", "category_id"], name: "index_categories_searches_on_search_id_and_category_id"
  end

  create_table "job_types", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_job_types_on_name"
  end

  create_table "job_types_searches", id: false, force: :cascade do |t|
    t.integer "search_id", null: false
    t.integer "job_type_id", null: false
    t.index ["job_type_id", "search_id"], name: "index_job_types_searches_on_job_type_id_and_search_id"
    t.index ["search_id", "job_type_id"], name: "index_job_types_searches_on_search_id_and_job_type_id"
  end

  create_table "locations", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_locations_on_name"
  end

  create_table "locations_searches", id: false, force: :cascade do |t|
    t.integer "search_id", null: false
    t.integer "location_id", null: false
    t.index ["location_id", "search_id"], name: "index_locations_searches_on_location_id_and_search_id"
    t.index ["search_id", "location_id"], name: "index_locations_searches_on_search_id_and_location_id"
  end

  create_table "resumes", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "filename"
    t.text "parsed_text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_resumes_on_user_id"
  end

  create_table "search_results", force: :cascade do |t|
    t.integer "search_id", null: false
    t.string "title"
    t.string "company"
    t.string "location"
    t.text "summary"
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.string "salary"
    t.string "work_setting"
    t.string "reference_number"
    t.index ["search_id"], name: "index_search_results_on_search_id"
  end

  create_table "searches", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "resume_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "completed"
    t.index ["resume_id"], name: "index_searches_on_resume_id"
    t.index ["user_id"], name: "index_searches_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "resumes", "users"
  add_foreign_key "search_results", "searches"
  add_foreign_key "searches", "resumes"
  add_foreign_key "searches", "users"
end
