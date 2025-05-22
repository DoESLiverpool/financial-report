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

ActiveRecord::Schema[8.0].define(version: 2025_05_22_100708) do
  create_table "accounting_periods", force: :cascade do |t|
    t.date "start_date"
    t.date "end_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "bank_account_entries", force: :cascade do |t|
    t.string "bank_account_name"
    t.string "description"
    t.date "date"
    t.string "entry_type"
    t.decimal "gross_value", precision: 10, scale: 2
    t.integer "sales_tax_rate"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "invoice_id"
    t.index ["invoice_id"], name: "index_bank_account_entries_on_invoice_id"
  end

  create_table "invoice_items", force: :cascade do |t|
    t.integer "invoice_id"
    t.string "item_type"
    t.decimal "quantity", precision: 10, scale: 2
    t.decimal "price", precision: 10, scale: 2
    t.string "description"
    t.decimal "sales_tax_rate", precision: 10, scale: 2
    t.decimal "subtotal", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_invoice_items_on_invoice_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.integer "bank_account_entry_id"
    t.string "contact"
    t.string "project"
    t.string "reference"
    t.date "date"
    t.integer "payment_terms_in_days", default: 0
    t.string "status"
    t.string "currency"
    t.string "comments"
    t.decimal "net_amount", precision: 10, scale: 2
    t.decimal "sales_tax_amount", precision: 10, scale: 2
    t.decimal "total_value", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bank_account_entry_id"], name: "index_invoices_on_bank_account_entry_id"
  end

  create_table "product_categories", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "product_category_descriptions", force: :cascade do |t|
    t.integer "product_category_id"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_category_id"], name: "index_product_category_descriptions_on_product_category_id"
  end

  add_foreign_key "bank_account_entries", "invoices"
end
