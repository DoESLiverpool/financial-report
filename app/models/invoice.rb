class Invoice < ApplicationRecord
  belongs_to :bank_account_entry, optional: true
  has_many :invoice_items
end
