class BankAccountEntry < ApplicationRecord
  belongs_to :invoice, optional: true
end
