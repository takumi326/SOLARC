# マスタに対し「その月の台帳 Transaction」を1件だけ付ける。支出・収入行を lock! してから存在チェックするので、
# 並行した同期リクエストで同月が二重付与されることは防げる（過去に溜まった重複は実績詳細から個別削除）。
class MonthlyActualsSyncService
  Result = Struct.new(:created_expense_count, :created_income_count, keyword_init: true)

  # expense_scope: :all（既定） / :one_time（単発のみ） / :recurring（定期のみ）
  def initialize(month:, expense_scope: :all)
    @month = month
    @expense_scope = expense_scope.to_sym
  end

  def call
    created_expense_count = 0
    created_income_count = 0

    ActiveRecord::Base.transaction do
      target_expenses.find_each do |expense|
        # 支出マスタ行をロックし、並行同期で同月の取引が二重に付くのを防ぐ
        expense.lock!
        tx_month = expense.payment_method.ledger_month_for_expense_accrual(@month)
        next if expense.expense_transactions.joins(:ledger_transaction).exists?(transactions: { month: tx_month })

        tx = Transaction.create!(month: tx_month, amount: -expense.amount)
        ExpenseTransaction.create!(expense: expense, ledger_transaction: tx)
        created_expense_count += 1
      end

      target_incomes.find_each do |income|
        income.lock!
        next if income.income_transactions.joins(:ledger_transaction).exists?(transactions: { month: @month })

        tx = Transaction.create!(month: @month, amount: income.amount)
        IncomeTransaction.create!(income: income, ledger_transaction: tx)
        created_income_count += 1
      end
    end

    Result.new(created_expense_count:, created_income_count:)
  end

  private

  def target_expenses
    one_time = Expense.where(expense_type: :one_time, start_month: @month)
    monthly = Expense.where(expense_type: :recurring, recurring_cycle: :monthly)
                     .where("start_month <= ?", @month)
                     .where("end_month IS NULL OR end_month >= ?", @month)
    yearly = Expense.where(expense_type: :recurring, recurring_cycle: :yearly, renewal_month: @month.month)
                    .where("start_month <= ?", @month)
                    .where("end_month IS NULL OR end_month >= ?", @month)

    case @expense_scope
    when :one_time
      one_time
    when :recurring
      monthly.or(yearly)
    else
      one_time.or(monthly).or(yearly)
    end
  end

  def target_incomes
    Income.where("start_month <= ?", @month)
          .where("end_month IS NULL OR end_month >= ?", @month)
          .where(income_type: :recurring)
          .or(Income.where(income_type: :one_time, start_month: @month))
  end
end
