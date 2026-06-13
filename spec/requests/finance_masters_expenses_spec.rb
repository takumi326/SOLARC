# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Finance masters expenses", type: :request do
  let!(:minor) { create(:minor_category) }
  let!(:payment_method) { create(:payment_method) }

  describe "PATCH /finance/masters/expenses/:id" do
    it "converts recurring expense to one_time and syncs actual" do
      expense = create(
        :expense,
        minor_category: minor,
        payment_method: payment_method,
        expense_type: :recurring,
        recurring_cycle: :monthly,
        start_month: Date.new(2026, 1, 1),
        end_month: Date.new(2026, 12, 1),
        amount: 3_000
      )

      patch finance_masters_expense_path(expense), params: {
        expense: {
          minor_category_id: minor.id,
          payment_method_id: payment_method.id,
          expense_type: "one_time",
          recurring_cycle: "monthly",
          amount: 3_000,
          start_month: "2026-06",
          memo: ""
        }
      }

      expect(response).to redirect_to(finance_masters_path(tab: "expenses", filter: "one_time"))
      expense.reload
      expect(expense.expense_type).to eq("one_time")
      expect(expense.end_month).to eq(Date.new(2026, 6, 1))
      ledger_month = payment_method.ledger_month_for_expense_accrual(Date.new(2026, 6, 1))
      expect(expense.expense_transactions.joins(:ledger_transaction).where(transactions: { month: ledger_month })).to exist
    end
  end

  describe "GET /finance/masters/expenses/:id/edit" do
    it "previews recurring form fields" do
      expense = create(:expense, minor_category: minor, payment_method: payment_method, expense_type: :one_time)

      get edit_finance_masters_expense_path(expense, expense_type: "recurring")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("開始月")
      expect(response.body).to include("定期の周期")
    end
  end
end
