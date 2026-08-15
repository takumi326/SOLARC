# frozen_string_literal: true

class FinanceYearSummaryBuilder
  include FiscalYearMonths

  AmountMode = Struct.new(:amount, :mode, keyword_init: true)
  Row = Struct.new(
    :month,
    :month_date,
    :income,
    :expense,
    :balance,
    :missing_recurring_income_actual,
    :missing_recurring_expense_actual,
    keyword_init: true
  ) do
    def missing_recurring_income_actual?
      missing_recurring_income_actual
    end

    def missing_recurring_expense_actual?
      missing_recurring_expense_actual
    end
  end

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
    missing_recurring_by_month = build_missing_recurring_index(fiscal_months)
    forecasts_by_key = build_forecasts_index(fiscal_months)

    rows = fiscal_months.each_with_object([]) do |m, acc|
      act = fiscal_actuals_by_month[m]
      missing = missing_recurring_by_month[m]
      forecast_expense = forecasts_by_key[[ "expense", m ]] || 0
      use_income_actual = act&.fetch(:has_income_actual, false)
      use_expense_actual = act&.fetch(:has_one_time_expense_actual, false)

      income_amount = use_income_actual ? act[:income_actual] : 0
      expense_amount = use_expense_actual ? act[:expense_actual] : forecast_expense
      income_mode = use_income_actual ? "実" : nil
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
        balance: AmountMode.new(amount: balance_amount, mode: balance_mode),
        missing_recurring_income_actual: missing[:missing_recurring_income_actual],
        missing_recurring_expense_actual: missing[:missing_recurring_expense_actual]
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

  def build_forecasts_index(fiscal_months)
    Forecast.where(month: fiscal_months).each_with_object({}) do |forecast, index|
      key = [ forecast.kind, forecast.month.beginning_of_month ]
      index[key] = forecast.amount.to_i
    end
  end

  def build_fiscal_actuals_index(fiscal_months)
    months = fiscal_months.map(&:beginning_of_month)
    balances = MonthlyBalance.where(month: months).index_by(&:month)

    income_totals = IncomeTransaction
      .joins(:ledger_transaction)
      .where(transactions: { month: months })
      .group("transactions.month")
      .sum("transactions.amount")

    expense_totals = ExpenseTransaction
      .joins(:ledger_transaction)
      .where(transactions: { month: months })
      .group("transactions.month")
      .sum("transactions.amount")

    one_time_months = ExpenseTransaction
      .joins(:ledger_transaction, :expense)
      .merge(Expense.expense_type_one_time)
      .where(transactions: { month: months })
      .distinct
      .pluck("transactions.month")
      .to_set

    fiscal_months.index_with do |month|
      m0 = month.beginning_of_month
      mb = balances[m0]

      {
        month: m0,
        has_income_actual: income_totals.key?(m0),
        has_one_time_expense_actual: one_time_months.include?(m0),
        income_actual: income_totals[m0].to_d.to_i,
        expense_actual: expense_totals[m0].to_d.abs.to_i,
        has_monthly_balance: mb.present?,
        monthly_balance_amount: mb&.amount
      }
    end
  end

  def build_missing_recurring_index(fiscal_months)
    months = fiscal_months.map(&:beginning_of_month)
    range_start = months.min
    range_end = months.max

    recurring_incomes = load_recurring_incomes(range_start, range_end)
    recurring_expenses = load_recurring_expenses(range_start, range_end)
    income_tx_by_income = build_income_transaction_index(months)
    expense_tx_index = build_recurring_expense_transaction_index(fiscal_months)

    fiscal_months.index_with do |month|
      m0 = month.beginning_of_month
      {
        missing_recurring_income_actual: missing_recurring_income?(
          m0, recurring_incomes, income_tx_by_income
        ),
        missing_recurring_expense_actual: missing_recurring_expense?(
          m0, recurring_expenses, expense_tx_index
        )
      }
    end
  end

  def load_recurring_incomes(range_start, range_end)
    Income.where(income_type: :recurring)
          .where("start_month <= ?", range_end)
          .where("end_month IS NULL OR end_month >= ?", range_start)
          .to_a
  end

  def load_recurring_expenses(range_start, range_end)
    monthly = Expense.where(expense_type: :recurring, recurring_cycle: :monthly)
                     .where("start_month <= ?", range_end)
                     .where("end_month IS NULL OR end_month >= ?", range_start)
    yearly = Expense.where(expense_type: :recurring, recurring_cycle: :yearly)
                    .where("start_month <= ?", range_end)
                    .where("end_month IS NULL OR end_month >= ?", range_start)

    monthly.or(yearly).includes(:payment_method).to_a
  end

  def income_active_in_month?(income, month)
    income.start_month <= month && (income.end_month.nil? || income.end_month >= month)
  end

  def recurring_expense_active_in_month?(expense, month)
    return false unless expense.start_month <= month
    return false unless expense.end_month.nil? || expense.end_month >= month

    if expense.recurring_cycle_monthly?
      true
    elsif expense.recurring_cycle_yearly?
      expense.renewal_month == month.month
    else
      false
    end
  end

  def build_income_transaction_index(months)
    IncomeTransaction
      .joins(:ledger_transaction)
      .where(transactions: { month: months })
      .pluck(:income_id, "transactions.month")
      .each_with_object(Hash.new { |h, k| h[k] = Set.new }) do |(income_id, tx_month), index|
        index[income_id] << tx_month
      end
  end

  def build_recurring_expense_transaction_index(fiscal_months)
    tx_months = fiscal_months.flat_map do |month|
      m0 = month.beginning_of_month
      [ m0, m0.next_month ]
    end.uniq

    ExpenseTransaction
      .joins(:ledger_transaction, :expense)
      .merge(Expense.expense_type_recurring)
      .where(transactions: { month: tx_months })
      .pluck(:expense_id, "transactions.month")
      .each_with_object({}) do |(expense_id, tx_month), index|
        index[[ expense_id, tx_month ]] = true
      end
  end

  def missing_recurring_income?(month, recurring_incomes, income_tx_by_income)
    recurring_incomes.any? do |income|
      income_active_in_month?(income, month) && !income_tx_by_income[income.id].include?(month)
    end
  end

  def missing_recurring_expense?(month, recurring_expenses, expense_tx_index)
    recurring_expenses.any? do |expense|
      next false unless recurring_expense_active_in_month?(expense, month)

      tx_month = expense.payment_method.ledger_month_for_expense_accrual(month)
      !expense_tx_index[[ expense.id, tx_month ]]
    end
  end

  def format_row_month(date)
    "#{date.year}/#{format('%02d', date.month)}"
  end
end
