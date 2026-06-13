# frozen_string_literal: true

class FinanceYearSummaryBuilder
  include FiscalYearMonths

  AmountMode = Struct.new(:amount, :mode, keyword_init: true)
  Row = Struct.new(:month, :month_date, :income, :expense, :balance, keyword_init: true)

  Result = Struct.new(
    :rows,
    :fiscal_months,
    :selected_month,
    :selected_index,
    :selected_row,
    :expected_balance,
    :previous_balance,
    :last_month_diff,
    keyword_init: true
  )

  def initialize(anchor_month:)
    @anchor_month = anchor_month.beginning_of_month
  end

  def call
    fiscal_months = fiscal_month_starts(@anchor_month)
    fiscal_actuals_by_month = build_fiscal_actuals_index(fiscal_months)
    forecasts_by_key = build_forecasts_index

    rows = fiscal_months.each_with_object([]) do |m, acc|
      act = fiscal_actuals_by_month[m]
      forecast_income = forecasts_by_key[[ "income", m ]] || 0
      forecast_expense = forecasts_by_key[[ "expense", m ]] || 0
      use_income_actual = act&.fetch(:has_income_actual, false)
      use_expense_actual = act&.fetch(:has_one_time_expense_actual, false)

      income_amount = use_income_actual ? act[:income_actual] : forecast_income
      expense_amount = use_expense_actual ? act[:expense_actual] : forecast_expense
      income_mode = use_income_actual ? "実" : "予"
      expense_mode = use_expense_actual ? "実" : "予"

      previous_balance = acc.empty? ? 0 : acc.last.balance.amount
      rolled_balance = previous_balance + income_amount - expense_amount
      stored_balance = act&.fetch(:has_monthly_balance, false) ? act[:monthly_balance_amount] : nil
      balance_amount = stored_balance.nil? ? rolled_balance : stored_balance
      balance_mode = act&.fetch(:has_monthly_balance, false) ? "実" : "予"

      acc << Row.new(
        month: format_row_month(m),
        month_date: m,
        income: AmountMode.new(amount: income_amount, mode: income_mode),
        expense: AmountMode.new(amount: expense_amount, mode: expense_mode),
        balance: AmountMode.new(amount: balance_amount, mode: balance_mode)
      )
    end

    selected_index = fiscal_months.index(@anchor_month)
    selected_row = selected_index ? rows[selected_index] : nil
    expected_balance = selected_row&.balance&.amount || 0
    previous_balance = selected_index && selected_index.positive? ? rows[selected_index - 1].balance.amount : 0

    Result.new(
      rows: rows,
      fiscal_months: fiscal_months,
      selected_month: @anchor_month,
      selected_index: selected_index || -1,
      selected_row: selected_row,
      expected_balance: expected_balance,
      previous_balance: previous_balance,
      last_month_diff: expected_balance - previous_balance
    )
  end

  def forecast_amount(kind, month)
    Forecast.find_by(kind: kind, month: month.beginning_of_month)&.amount.to_i || 0
  end

  private

  def build_forecasts_index
    Forecast.all.each_with_object({}) do |forecast, index|
      key = [ forecast.kind, forecast.month.beginning_of_month ]
      index[key] = forecast.amount.to_i
    end
  end

  def build_fiscal_actuals_index(fiscal_months)
    fiscal_months.index_with { |m| fiscal_actual_row(m) }
  end

  def fiscal_actual_row(month)
    m0 = month.beginning_of_month
    mb = MonthlyBalance.find_by(month: m0)
    {
      month: m0,
      has_income_actual: income_ledger_exists?(m0),
      has_expense_actual: expense_ledger_exists?(m0),
      has_one_time_expense_actual: one_time_expense_ledger_exists?(m0),
      income_actual: actual_income_total(m0),
      expense_actual: actual_expense_total(m0),
      has_monthly_balance: mb.present?,
      monthly_balance_amount: mb&.amount
    }
  end

  def format_row_month(date)
    "#{date.year}/#{format('%02d', date.month)}"
  end

  def income_ledger_exists?(month)
    IncomeTransaction.joins(:ledger_transaction).exists?(transactions: { month: month })
  end

  def expense_ledger_exists?(month)
    ExpenseTransaction.joins(:ledger_transaction).exists?(transactions: { month: month })
  end

  def one_time_expense_ledger_exists?(month)
    ExpenseTransaction
      .joins(:ledger_transaction, :expense)
      .merge(Expense.expense_type_one_time)
      .exists?(transactions: { month: month })
  end

  def actual_income_total(month)
    IncomeTransaction.joins(:ledger_transaction)
                     .where(transactions: { month: month })
                     .sum("transactions.amount").to_d.to_i
  end

  def actual_expense_total(month)
    ExpenseTransaction.joins(:ledger_transaction)
                      .where(transactions: { month: month })
                      .sum("transactions.amount").to_d.abs.to_i
  end
end
