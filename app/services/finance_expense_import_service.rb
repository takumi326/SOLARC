# frozen_string_literal: true

class FinanceExpenseImportService
  Result = Struct.new(:imported_count, :touched_months, keyword_init: true)

  def initialize(rows:)
    @rows = rows
  end

  def call
    raise ArgumentError, "取り込む行がありません" if @rows.empty?

    missing_card = @rows.find { |row| row.payment_method_id.blank? }
    if missing_card
      raise ArgumentError,
            "No.#{missing_card.line_number}: card_id「#{missing_card.card_id}」に対応する支払方法が未設定です"
    end

    touched_months = Set.new
    imported_count = 0
    payment_methods = PaymentMethod.where(id: @rows.map(&:payment_method_id).uniq).index_by(&:id)

    ActiveRecord::Base.transaction do
      @rows.each do |row|
        payment_method = payment_methods.fetch(row.payment_method_id)
        raise ArgumentError, "支払方法が不正です（行 #{row.line_number}）" unless payment_method.method_type == "card"

        payment_method.update!(ledger_charge_timing: "next_month")

        Expense.create!(
          minor_category_id: row.minor_category_id,
          payment_method: payment_method,
          expense_type: :one_time,
          recurring_cycle: :monthly,
          renewal_month: nil,
          amount: row.amount,
          start_month: row.month_date,
          end_month: row.month_date,
          memo: row.memo,
          imported_at: Time.current
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

  # 明細との突合に使う一覧。単発の実績に加えて、その月に発生するカード払いの定期も混ぜる。
  # 定期は取り込み対象ではないが、明細には載るので不足扱いされないよう台帳側に出しておく。
  def self.existing_comparison_rows(compare_month:, pending_rows:)
    month_first = compare_month.beginning_of_month
    expenses = Expense.joins(minor_category: :major_category)
                      .joins(:payment_method)
                      .includes({ minor_category: :major_category }, :payment_method)
                      .select { |e| comparable_with_statement?(e, month_first) }

    month_label = month_first.strftime("%Y-%m")
    expenses.map do |expense|
      minor = expense.minor_category
      recurring = !expense.expense_type_one_time?
      row = {
        id: expense.id,
        recurring: recurring,
        month_label: recurring ? month_label : expense.start_month.strftime("%Y-%m"),
        category_path: "#{minor.major_category.name} / #{minor.name}",
        amount: expense.amount.to_i,
        memo: expense.memo,
        minor_category_id: minor.id,
        payment_method_id: expense.payment_method_id,
        card_name: expense.payment_method.name
      }
      row[:duplicate_with_pending] = pending_rows.any? do |pending|
        pending.month_label == month_label && same_expense?(row, pending)
      end
      row
    end.sort_by { |row| [ row[:duplicate_with_pending] ? 0 : 1, row[:category_path], row[:amount], row[:id] ] }
  end

  # 定期は請求カードを付け替えることがあるので、カード違いでも同じサブスクとして扱う
  def self.same_expense?(existing_row, pending_row)
    return false unless existing_row[:minor_category_id] == pending_row.minor_category_id
    return false unless existing_row[:amount] == pending_row.amount

    existing_row[:recurring] || existing_row[:payment_method_id] == pending_row.payment_method_id
  end

  def self.comparable_with_statement?(expense, month_first)
    return false unless expense_applies_to_accrual_month?(expense, month_first)
    return true if expense.expense_type_one_time?

    expense.payment_method&.method_type == "card"
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
