class SwitchInvoiceReferences < ActiveRecord::Migration[6.0]
  def change
    add_reference :bank_account_entries, :invoice, foreign_key: true, required: false
  end
end
