class CreateInvoices < ActiveRecord::Migration[5.1]
  def change
    create_table :invoices do |t|
      t.references :bank_account_entry, required: false

      t.string :contact, required: true
      t.string :project
      t.string :reference, required: true
      t.date :date, required: true
      t.integer :payment_terms_in_days, required: true, default: 0
      t.string :status, required: true
      t.string :currency
      t.string :comments
      t.decimal :net_amount, required: true, precision: 10, scale: 2
      t.decimal :sales_tax_amount, required: true, precision: 10, scale: 2
      t.decimal :total_value, required: true, precision: 10, scale: 2
      t.timestamps
    end
  end
end
