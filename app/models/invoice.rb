class Invoice < ApplicationRecord
  belongs_to :bank_account_entry, optional: true
end
