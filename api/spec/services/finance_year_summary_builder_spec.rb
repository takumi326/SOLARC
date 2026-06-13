# frozen_string_literal: true

require "rails_helper"

RSpec.describe FinanceYearSummaryBuilder do
  describe "#call" do
    let(:anchor) { Date.new(2026, 5, 1) }

    it "uses forecast when no actuals exist" do
      create(:forecast, kind: :income, month: anchor, amount: 200_000)
      create(:forecast, kind: :expense, month: anchor, amount: 80_000)

      result = described_class.new(anchor_month: anchor).call
      row = result.selected_row

      expect(row.income.amount).to eq(200_000)
      expect(row.income.mode).to eq("予")
      expect(row.expense.amount).to eq(80_000)
      expect(row.expense.mode).to eq("予")
      expect(result.rows.size).to eq(12)
    end

    it "uses stored monthly balance when present" do
      create(:forecast, kind: :income, month: anchor, amount: 100_000)
      create(:forecast, kind: :expense, month: anchor, amount: 10_000)
      MonthlyBalance.create!(month: anchor, amount: 500_000)

      result = described_class.new(anchor_month: anchor).call
      expect(result.selected_row.balance.amount).to eq(500_000)
      expect(result.selected_row.balance.mode).to eq("実")
    end
  end
end
