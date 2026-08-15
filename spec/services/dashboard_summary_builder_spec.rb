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

    it "sorts expense line items by major then minor category" do
      month = Date.new(2026, 5, 1)
      major_b = create(:major_category, name: "B大")
      major_a = create(:major_category, name: "A大")
      minor_b2 = create(:minor_category, major_category: major_b, name: "B小2")
      minor_b1 = create(:minor_category, major_category: major_b, name: "B小1")
      minor_a = create(:minor_category, major_category: major_a, name: "A小")

      [ minor_b2, minor_a, minor_b1 ].each do |minor|
        expense = create(:expense, minor_category: minor, start_month: month, end_month: month)
        tx = Transaction.create!(month: month, amount: -1_000)
        ExpenseTransaction.create!(expense: expense, ledger_transaction: tx)
      end

      labels = described_class.new(month: month).call[:expense_line_items].map { |row| [ row[:major], row[:minor] ] }

      expect(labels).to eq([ [ "A大", "A小" ], [ "B大", "B小1" ], [ "B大", "B小2" ] ])
    end
  end
end
