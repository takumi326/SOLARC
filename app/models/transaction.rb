class Transaction < ApplicationRecord
  has_one :expense_transaction, dependent: :destroy
  has_one :income_transaction, dependent: :destroy
end
