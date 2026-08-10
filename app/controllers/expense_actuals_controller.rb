# frozen_string_literal: true

class ExpenseActualsController < ApplicationController
  include FinanceMonthParams

  before_action :set_expense

  def index
    @actuals = @expense.expense_transactions
                       .joins(:ledger_transaction)
                       .includes(:ledger_transaction)
                       .order(Arel.sql("transactions.month ASC, expense_transactions.id ASC"))
                       .map(&:ledger_transaction)
  end

  def edit
    @transaction = find_transaction
  end

  def update
    @transaction = find_transaction
    new_amount = -params.dig(:actual, :amount).to_d.abs

    @transaction.amount = new_amount
    if @transaction.save
      redirect_to finance_expense_actuals_path(@expense), notice: "実績を更新しました。"
    else
      flash.now[:alert] = @transaction.errors.full_messages.join(" ")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    transaction = find_transaction
    transaction.destroy!
    redirect_to finance_expense_actuals_path(@expense), notice: "実績を削除しました。"
  end

  def bulk_from_month
    unless @expense.expense_type_recurring?
      redirect_to finance_expense_actuals_path(@expense), alert: "定期の支出のみ一括変更できます"
      return
    end

    from_month = parse_month_param(params[:from_month])
    amount = params[:amount].to_d.abs
    BulkUpdateMasterActualsFromMonthService.call(
      master: @expense,
      from_month: from_month.to_s,
      amount: amount,
      negative: true
    )
    redirect_to finance_expense_actuals_path(@expense), notice: "指定月以降の実績を一括更新しました。"
  rescue ArgumentError => e
    redirect_to finance_expense_actuals_path(@expense), alert: e.message
  end

  private

  def set_expense
    @expense = Expense.includes(minor_category: :major_category).find(params[:expense_id])
  end

  def find_transaction
    et = @expense.expense_transactions.find_by!(transaction_id: params[:id])
    et.ledger_transaction
  end
end
