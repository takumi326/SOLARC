# frozen_string_literal: true

class IncomeActualsController < ApplicationController
  include FinanceMonthParams

  before_action :set_income

  def index
    @actuals = @income.income_transactions
                      .joins(:ledger_transaction)
                      .includes(:ledger_transaction)
                      .order(Arel.sql("transactions.month ASC, income_transactions.id ASC"))
                      .map(&:ledger_transaction)
  end

  def edit
    @transaction = find_transaction
  end

  def update
    @transaction = find_transaction
    new_amount = params.dig(:actual, :amount).to_d.abs

    @transaction.amount = new_amount
    if @transaction.save
      redirect_to finance_income_actuals_path(@income), notice: "実績を更新しました。"
    else
      flash.now[:alert] = @transaction.errors.full_messages.join(" ")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    transaction = find_transaction
    transaction.destroy!
    redirect_to finance_income_actuals_path(@income), notice: "実績を削除しました。"
  end

  def bulk_from_month
    unless @income.income_type_recurring?
      redirect_to finance_income_actuals_path(@income), alert: "定期の収入のみ一括変更できます"
      return
    end

    from_month = parse_month_param(params[:from_month])
    amount = params[:amount].to_d.abs
    BulkUpdateMasterActualsFromMonthService.call(
      master: @income,
      from_month: from_month.to_s,
      amount: amount,
      negative: false
    )
    redirect_to finance_income_actuals_path(@income), notice: "指定月以降の実績を一括更新しました。"
  rescue ArgumentError => e
    redirect_to finance_income_actuals_path(@income), alert: e.message
  end

  private

  def set_income
    @income = Income.includes(minor_category: :major_category).find(params[:income_id])
  end

  def find_transaction
    it = @income.income_transactions.find_by!(transaction_id: params[:id])
    it.ledger_transaction
  end
end
