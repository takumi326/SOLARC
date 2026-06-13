# frozen_string_literal: true

require "rails_helper"

RSpec.describe DashboardSummaryBuilder do
  describe "#call" do
    it "returns expense breakdown rows for the month" do
      month = Date.new(2026, 5, 1)
      expense = create(:expense, start_month: month, end_month: month)
      tx = Transaction.create!(month: month, amount: -12_000)
      ExpenseTransaction.create!(expense: expense, ledger_transaction: tx)

      result = described_class.new(month: month).call

      expect(result[:expense_by_payment].first[:amount]).to eq(12_000)
      expect(result[:expense_line_items].size).to eq(1)
    end
  end
end
