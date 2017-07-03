class CreateBankAccountEntries < ActiveRecord::Migration[5.1]
  def change
    create_table :bank_account_entries do |t|
      t.string :bank_account_name, required: true
      t.string :description, required: true
      t.date :date, required: true
      t.string :entry_type, required: true
      t.decimal :gross_value, required: true, precision: 10, scale: 2
      t.integer :sales_tax_rate, required: true

      t.timestamps
    end
  end
end
