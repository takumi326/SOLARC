# frozen_string_literal: true

class DashboardSummaryBuilder
  def initialize(month:)
    @month = month.beginning_of_month
  end

  def call
    {
      month: @month,
      expense_by_payment: expense_by_payment,
      expense_by_category_groups: expense_by_category_groups,
      expense_line_items: expense_line_items,
      monthly_balance: monthly_balance_amount
    }
  end

  private

  attr_reader :month

  def monthly_balance_amount
    @monthly_balance_amount ||= MonthlyBalance.find_by(month: month)&.amount || 0
  end

  def expense_rows
    @expense_rows ||= ExpenseTransaction
      .joins(:ledger_transaction, expense: [ :payment_method, { minor_category: :major_category } ])
      .where(transactions: { month: month })
  end

  def expense_line_items
    expense_rows
      .preload(expense: [ :payment_method, { minor_category: :major_category } ])
      .order(Arel.sql("payment_methods.name ASC, expenses.id ASC"))
      .map do |et|
        e = et.expense
        {
          expense_id: e.id,
          expense_type: e.expense_type,
          recurring_cycle: (e.expense_type_recurring? ? e.recurring_cycle : nil),
          major: e.minor_category.major_category.name,
          minor: e.minor_category.name,
          payment: e.payment_method.name,
          amount: et.ledger_transaction.amount.to_d.abs,
          memo: e.memo
        }
      end
  end

  def expense_by_payment
    grouped = expense_rows.group("payment_methods.id", "payment_methods.name").sum("transactions.amount")

    grouped.map do |(_payment_id, payment_name), amount|
      {
        label: payment_name,
        amount: amount.to_d.abs,
        mode: "実"
      }
    end.sort_by { |row| row[:label] }
  end

  def expense_by_category_groups
    grouped = expense_rows.group("major_categories.id", "major_categories.name", "minor_categories.id", "minor_categories.name")
                          .sum("transactions.amount")

    by_major = {}
    grouped.each do |(_major_id, major_name, _minor_id, minor_name), amount|
      by_major[major_name] ||= []
      by_major[major_name] << {
        label: minor_name,
        amount: amount.to_d.abs,
        mode: "実"
      }
    end

    by_major.keys.sort.map do |major_name|
      {
        major: major_name,
        mode: "実",
        minors: by_major[major_name].sort_by { |row| row[:label] }
      }
    end
  end
end
