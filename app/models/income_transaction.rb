class IncomeTransaction < ApplicationRecord
  belongs_to :income
  belongs_to :ledger_transaction, class_name: "Transaction", foreign_key: :transaction_id, inverse_of: :income_transaction
end
