class CreateInvoiceItems < ActiveRecord::Migration[5.1]
  def change
    create_table :invoice_items do |t|
      t.references :invoice
      
      t.string :item_type, required: true
      t.decimal :quantity, required: true, precision: 10, scale: 2
      t.decimal :price, required: true, precision: 10, scale: 2
      t.string :description, required: true
      t.decimal :sales_tax_rate, required: true, precision: 10, scale: 2
      t.decimal :subtotal, required: true, precision: 10, scale: 2

      t.timestamps
    end
  end
end
