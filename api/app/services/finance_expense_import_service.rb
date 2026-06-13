# frozen_string_literal: true

class FinanceExpenseImportService
  FIXED_PAYMENT_METHOD_NAME = "Amazonカード"

  Result = Struct.new(:imported_count, :touched_months, keyword_init: true)

  def initialize(rows:, payment_method:)
    @rows = rows
    @payment_method = payment_method
  end

  def call
    raise ArgumentError, "取り込む行がありません" if @rows.empty?
    raise ArgumentError, "支払方法が不正です" unless @payment_method&.method_type == "card"

    touched_months = Set.new
    imported_count = 0

    ActiveRecord::Base.transaction do
      @payment_method.update!(ledger_charge_timing: "next_month")

      @rows.each do |row|
        Expense.create!(
          minor_category_id: row.minor_category_id,
          payment_method: @payment_method,
          expense_type: :one_time,
          recurring_cycle: :monthly,
          renewal_month: nil,
          amount: row.amount,
          start_month: row.month_date,
          end_month: row.month_date,
          memo: row.memo
        )
        touched_months << row.month_date
        imported_count += 1
      end
    end

    touched_months.each do |month|
      MonthlyActualsSyncService.new(month: month, expense_scope: :one_time).call
    end

    Result.new(imported_count: imported_count, touched_months: touched_months.to_a.sort)
  end

  def self.fixed_payment_method
    PaymentMethod.find_by(name: FIXED_PAYMENT_METHOD_NAME)
  end

  def self.existing_one_time_rows(compare_month:, pending_rows:)
    month_first = compare_month.beginning_of_month
    expenses = Expense.expense_type_one_time
                      .joins(minor_category: :major_category)
                      .includes(minor_category: :major_category)
                      .select { |e| expense_applies_to_accrual_month?(e, month_first) }

    expenses.map do |expense|
      minor = expense.minor_category
      amount = expense.amount.to_i
      duplicate = pending_rows.any? do |pr|
        pr.month_label == compare_month.strftime("%Y-%m") &&
          pr.minor_category_id == minor.id &&
          pr.amount == amount
      end
      {
        id: expense.id,
        month_label: expense.start_month.strftime("%Y-%m"),
        category_path: "#{minor.major_category.name} / #{minor.name}",
        amount: amount,
        memo: expense.memo,
        minor_category_id: minor.id,
        duplicate_with_pending: duplicate
      }
    end.sort_by { |row| [ row[:duplicate_with_pending] ? 0 : 1, row[:category_path], row[:amount], row[:id] ] }
  end

  def self.expense_applies_to_accrual_month?(expense, accrual_month_first)
    start = expense.start_month.beginning_of_month
    finish = expense.end_month&.beginning_of_month
    return false if accrual_month_first < start
    return false if finish.present? && accrual_month_first > finish

    if expense.expense_type_one_time?
      return accrual_month_first == start
    end

    if expense.recurring_cycle_monthly?
      return true
    end

    if expense.recurring_cycle_yearly?
      return expense.renewal_month == accrual_month_first.month
    end

    false
  end
end
