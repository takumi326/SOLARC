# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Finance actuals", type: :request do
  def create_recurring_expense_with_actual(month: Date.new(2026, 5, 1), amount: 10_000)
    expense = create(:expense, expense_type: :recurring, start_month: month, amount: amount)
    tx = Transaction.create!(month: month, amount: -amount)
    ExpenseTransaction.create!(expense: expense, ledger_transaction: tx)
    [ expense, tx ]
  end

  def create_recurring_income_with_actual(month: Date.new(2026, 5, 1), amount: 30_000)
    major = create(:major_category, kind: :income)
    minor = create(:minor_category, major_category: major)
    income = create(:income, minor_category: minor, income_type: :recurring, start_month: month, amount: amount)
    tx = Transaction.create!(month: month, amount: amount)
    IncomeTransaction.create!(income: income, ledger_transaction: tx)
    [ income, tx ]
  end

  describe "PATCH expense actual" do
    it "updates and redirects to finance expense actuals index" do
      expense, tx = create_recurring_expense_with_actual

      patch finance_expense_actual_path(expense, tx), params: {
        actual: { month: "2026-05", amount: 12_000 }
      }

      expect(response).to redirect_to(finance_expense_actuals_path(expense))
      expect(tx.reload.amount).to eq(-12_000)
    end
  end

  describe "DELETE expense actual" do
    it "destroys and redirects to finance expense actuals index" do
      expense, tx = create_recurring_expense_with_actual

      delete finance_expense_actual_path(expense, tx)

      expect(response).to redirect_to(finance_expense_actuals_path(expense))
      expect(Transaction.exists?(tx.id)).to be(false)
    end
  end

  describe "PATCH income actual" do
    it "updates and redirects to finance income actuals index" do
      income, tx = create_recurring_income_with_actual

      patch finance_income_actual_path(income, tx), params: {
        actual: { month: "2026-05", amount: 35_000 }
      }

      expect(response).to redirect_to(finance_income_actuals_path(income))
      expect(tx.reload.amount).to eq(35_000)
    end
  end

  describe "DELETE income actual" do
    it "destroys and redirects to finance income actuals index" do
      income, tx = create_recurring_income_with_actual

      delete finance_income_actual_path(income, tx)

      expect(response).to redirect_to(finance_income_actuals_path(income))
      expect(Transaction.exists?(tx.id)).to be(false)
    end
  end
end
