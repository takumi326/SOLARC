class ExpenseTransaction < ApplicationRecord
  belongs_to :expense
  belongs_to :ledger_transaction, class_name: "Transaction", foreign_key: :transaction_id, inverse_of: :expense_transaction
end
