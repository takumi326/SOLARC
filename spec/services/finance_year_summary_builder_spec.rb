# frozen_string_literal: true

require "rails_helper"

RSpec.describe FinanceYearSummaryBuilder do
  describe "#call" do
    let(:anchor) { Date.new(2026, 5, 1) }

    it "uses expense forecast when no actuals exist and ignores income forecast" do
      create(:forecast, kind: :income, month: anchor, amount: 200_000)
      create(:forecast, kind: :expense, month: anchor, amount: 80_000)

      result = described_class.new(anchor_month: anchor).call
      row = result.selected_row

      expect(row.income.amount).to eq(0)
      expect(row.income.mode).to be_nil
      expect(row.expense.amount).to eq(80_000)
      expect(row.expense.mode).to eq("予")
      expect(result.rows.size).to eq(12)
    end

    it "uses actual income when present" do
      month = anchor
      income = create(:income, start_month: month, end_month: month)
      tx = Transaction.create!(month: month, amount: 250_000)
      IncomeTransaction.create!(income: income, ledger_transaction: tx)

      result = described_class.new(anchor_month: anchor).call
      row = result.selected_row

      expect(row.income.amount).to eq(250_000)
      expect(row.income.mode).to eq("実")
    end

    it "uses stored monthly balance when present" do
      create(:forecast, kind: :expense, month: anchor, amount: 10_000)
      MonthlyBalance.create!(month: anchor, amount: 500_000)

      result = described_class.new(anchor_month: anchor).call
      expect(result.selected_row.balance.amount).to eq(500_000)
      expect(result.selected_row.balance.mode).to eq("実")
    end

    it "flags missing recurring income when a recurring master has no transaction" do
      create(:income, income_type: :recurring, start_month: anchor, end_month: nil)

      result = described_class.new(anchor_month: anchor).call
      row = result.selected_row

      expect(row.missing_recurring_income_actual?).to be(true)
      expect(row.missing_recurring_expense_actual?).to be(false)
    end

    it "clears missing recurring income after sync transaction exists" do
      month = anchor
      income = create(:income, income_type: :recurring, start_month: month, end_month: nil)
      tx = Transaction.create!(month: month, amount: 250_000)
      IncomeTransaction.create!(income: income, ledger_transaction: tx)

      result = described_class.new(anchor_month: anchor).call

      expect(result.selected_row.missing_recurring_income_actual?).to be(false)
    end

    it "flags missing recurring expense when a recurring master has no transaction" do
      create(
        :expense,
        expense_type: :recurring,
        recurring_cycle: :monthly,
        start_month: anchor,
        end_month: nil
      )

      result = described_class.new(anchor_month: anchor).call

      expect(result.selected_row.missing_recurring_expense_actual?).to be(true)
      expect(result.selected_row.missing_recurring_income_actual?).to be(false)
    end

    it "clears missing recurring expense after sync transaction exists" do
      month = anchor
      payment_method = create(:payment_method, method_type: "bank_withdrawal")
      expense = create(
        :expense,
        payment_method: payment_method,
        expense_type: :recurring,
        recurring_cycle: :monthly,
        start_month: month,
        end_month: nil
      )
      tx_month = payment_method.ledger_month_for_expense_accrual(month)
      tx = Transaction.create!(month: tx_month, amount: -expense.amount)
      ExpenseTransaction.create!(expense: expense, ledger_transaction: tx)

      result = described_class.new(anchor_month: anchor).call

      expect(result.selected_row.missing_recurring_expense_actual?).to be(false)
    end

    it "does not flag yearly recurring expense outside renewal month" do
      create(
        :expense,
        expense_type: :recurring,
        recurring_cycle: :yearly,
        renewal_month: 6,
        start_month: Date.new(2026, 1, 1),
        end_month: nil
      )

      result = described_class.new(anchor_month: anchor).call

      expect(result.selected_row.missing_recurring_expense_actual?).to be(false)
    end
  end
end
