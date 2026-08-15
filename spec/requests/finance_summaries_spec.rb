# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Finance summaries", type: :request do
  describe "GET /finance" do
    it "shows finance summary page" do
      get finance_summary_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今年度サマリ")
      expect(response.body).to include("月末残高の作成")
    end

    it "shows selected month from param" do
      get finance_summary_path(month: "2026-05")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('value="2026-05"')
    end

    it "keeps import next to bulk forecast edit and hides the old month bar" do
      get finance_summary_path
      expect(response.body).to include("取込")
      expect(response.body).to include("予測をまとめて編集")
      expect(response.body).not_to include("月末予想残高（予）")
      expect(response.body).not_to include("単発の支出を追加")
      expect(response.body).not_to include("今月へ")
    end
  end

  describe "PATCH /finance/forecasts" do
    it "upserts expense forecast and redirects" do
      patch finance_forecast_path, params: {
        forecast: { kind: "expense", month: "2026-05-01", amount: 250_000 }
      }
      expect(response).to redirect_to(finance_summary_path(month: "2026-05"))
      expect(Forecast.find_by(kind: :expense, month: Date.new(2026, 5, 1)).amount).to eq(250_000)
    end

    it "ignores income kind and saves as expense forecast" do
      patch finance_forecast_path, params: {
        forecast: { kind: "income", month: "2026-05-01", amount: 250_000 }
      }
      expect(response).to redirect_to(finance_summary_path(month: "2026-05"))
      expect(Forecast.find_by(kind: :income, month: Date.new(2026, 5, 1))).to be_nil
      expect(Forecast.find_by(kind: :expense, month: Date.new(2026, 5, 1)).amount).to eq(250_000)
    end

    it "accepts month in YYYY-MM format" do
      patch finance_forecast_path, params: {
        forecast: { kind: "expense", month: "2026-05", amount: 180_000 }
      }
      expect(response).to redirect_to(finance_summary_path(month: "2026-05"))
      expect(Forecast.find_by(kind: :expense, month: Date.new(2026, 5, 1)).amount).to eq(180_000)
    end
  end

  describe "POST /finance/bulk_forecasts" do
    it "saves fiscal year expense forecasts without type error" do
      post finance_bulk_forecasts_path, params: {
        anchor_month: "2026-05",
        rows: {
          "0" => { expense: "190_000" },
          "1" => { expense: "195_000" }
        }
      }

      expect(response).to redirect_to(finance_summary_path(month: "2026-05"))
      expect(Forecast.find_by(kind: :income, month: Date.new(2026, 4, 1))).to be_nil
      expect(Forecast.find_by(kind: :expense, month: Date.new(2026, 5, 1)).amount).to eq(195_000)
    end
  end

  describe "POST /finance/monthly_balance" do
    it "saves monthly balance" do
      post finance_monthly_balance_path, params: {
        monthly_balance: { month: "2026-05", amount: 1_500_000 }
      }
      expect(response).to redirect_to(finance_summary_path(month: "2026-05"))
      expect(MonthlyBalance.find_by(month: Date.new(2026, 5, 1)).amount).to eq(1_500_000)
    end
  end

  describe "GET /finance/expense_breakdown" do
    it "shows the total of all expense line items" do
      month = Date.new(2026, 5, 1)
      expense = create(:expense, start_month: month, end_month: month)
      tx = Transaction.create!(month: month, amount: -12_000)
      ExpenseTransaction.create!(expense: expense, ledger_transaction: tx)

      get finance_expense_breakdown_path(month: "2026-05", view: "lines")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("支出の内訳")
      expect(response.body.scan("合計").size).to be >= 1
      expect(response.body).to include("¥12,000")
    end
  end

  describe "GET /finance/masters" do
    it "shows masters hub" do
      get finance_masters_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("支出・収入")
    end

    it "shows master memo and month grouping for one-time expenses" do
      minor = create(:minor_category, name: "Steam")
      payment_method = create(:payment_method)
      create(
        :expense,
        minor_category: minor,
        payment_method: payment_method,
        expense_type: :one_time,
        start_month: Date.new(2026, 6, 1),
        amount: 1_000,
        memo: "夏セール"
      )

      get finance_masters_path(tab: "expenses", filter: "one_time", group: "month")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("マスタのメモ")
      expect(response.body).to include("夏セール")
      expect(response.body).to include("2026/06")
      expect(response.body).not_to include("種別")
    end
  end
end
