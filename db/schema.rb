# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170630204210) do

  create_table "bank_account_entries", force: :cascade do |t|
    t.string "bank_account_name"
    t.string "description"
    t.date "date"
    t.string "entry_type"
    t.decimal "gross_value", precision: 10, scale: 2
    t.integer "sales_tax_rate"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

end
