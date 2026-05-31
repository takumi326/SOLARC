module Api
  class ExpensesController < ApplicationController
    before_action :set_expense, only: [ :update, :destroy, :actuals, :bulk_update_actuals_from_month, :update_actual, :destroy_actual ]
    before_action :ensure_expense!, only: [ :update, :destroy, :actuals, :bulk_update_actuals_from_month, :update_actual, :destroy_actual ]

    def index
      expenses = Expense.joins(:minor_category)
                        .preload(:minor_category, :payment_method)
                        .order(Arel.sql("minor_categories.name ASC, expenses.id ASC"))
      render json: { data: expenses.map { |e| expense_json(e) } }
    end

    def create
      expense = Expense.new(expense_params)
      if expense.save
        render json: { data: expense_json(expense) }, status: :created
      else
        render_validation_error(expense)
      end
    end

    def update
      if @expense.update(expense_params)
        render json: { data: expense_json(@expense) }
      else
        render_validation_error(@expense)
      end
    end

    def destroy
      @expense.destroy!
      head :no_content
    end

    def actuals
      rows = @expense.expense_transactions
                     .joins(:ledger_transaction)
                     .includes(:ledger_transaction)
                     .order(Arel.sql("transactions.month ASC, expense_transactions.id ASC"))
      render json: {
        data: rows.map { |row| expense_actual_row_json(row.ledger_transaction) }
      }
    end

    def bulk_update_actuals_from_month
      unless @expense.expense_type_recurring?
        return render json: {
          error: { code: "bad_request", message: "定期の支出のみ一括変更できます" }
        }, status: :unprocessable_entity
      end

      attrs = bulk_actual_params
      result = BulkUpdateMasterActualsFromMonthService.call(
        master: @expense,
        from_month: attrs[:from_month],
        amount: attrs[:amount],
        negative: true
      )
      render json: {
        data: {
          updated_count: result.updated_count,
          from_month: Date.parse(attrs[:from_month]).beginning_of_month.iso8601,
          amount: attrs[:amount].to_d.abs
        }
      }
    rescue ArgumentError => e
      render json: { error: { code: "bad_request", message: e.message } }, status: :bad_request
    end

    def update_actual
      tx_id = Integer(params[:transaction_id])
      et = @expense.expense_transactions.find_by(transaction_id: tx_id)
      unless et
        render json: { error: { code: "not_found", message: "この支出に紐づく実績取引が見つかりません" } }, status: :not_found
        return
      end

      attrs = actual_ledger_params
      tx = et.ledger_transaction
      new_month = attrs[:month].present? ? Date.parse(attrs[:month]).beginning_of_month : tx.month
      new_amount =
        if attrs[:amount].present?
          -attrs[:amount].to_d.abs
        else
          tx.amount
        end

      if duplicate_expense_ledger_month?(expense: @expense, month: new_month, except_transaction_id: tx.id)
        render json: {
          error: { code: "duplicate_month", message: "同じ月に別の実績が既にあります" }
        }, status: :unprocessable_entity
        return
      end

      tx.month = new_month
      tx.amount = new_amount
      if tx.save
        render json: { data: expense_actual_row_json(tx) }
      else
        render json: {
          error: { code: "validation_error", message: "実績の更新に失敗しました", details: tx.errors }
        }, status: :unprocessable_entity
      end
    rescue ArgumentError, TypeError
      render json: { error: { code: "bad_request", message: "transaction_id または日付・金額が不正です" } }, status: :bad_request
    end

    # 重複した実績取引を1件ずつ削除（台帳 Transaction ごと破棄）
    def destroy_actual
      tx_id = Integer(params[:transaction_id])
      et = @expense.expense_transactions.find_by(transaction_id: tx_id)
      unless et
        render json: { error: { code: "not_found", message: "この支出に紐づく実績取引が見つかりません" } }, status: :not_found
        return
      end

      et.ledger_transaction.destroy!
      head :no_content
    rescue ArgumentError, TypeError
      render json: { error: { code: "bad_request", message: "transaction_id が不正です" } }, status: :bad_request
    end

    private

    def expense_actual_row_json(tx)
      {
        transaction_id: tx.id,
        month: tx.month,
        amount: tx.amount.to_d.abs
      }
    end

    def actual_ledger_params
      p = params.require(:actual).permit(:month, :amount)
      { month: p[:month].to_s.presence, amount: p[:amount].to_s.presence }
    end

    def bulk_actual_params
      p = params.expect(bulk: [ :from_month, :amount ])
      {
        from_month: p[:from_month].to_s,
        amount: p[:amount].to_s
      }
    end

    def duplicate_expense_ledger_month?(expense:, month:, except_transaction_id:)
      expense.expense_transactions
             .joins(:ledger_transaction)
             .where.not(transaction_id: except_transaction_id)
             .exists?(transactions: { month: month })
    end

    def set_expense
      @expense = Expense.find_by(id: params[:id])
    end

    def ensure_expense!
      return if @expense.present?

      render json: { error: { code: "not_found", message: "Expense not found" } }, status: :not_found
    end

    def expense_params
      params.expect(expense: [
        :minor_category_id, :payment_method_id, :expense_type, :recurring_cycle, :renewal_month, :amount, :start_month, :end_month, :memo
      ])
    end

    def expense_json(expense)
      expense.as_json(only: [
        :id, :minor_category_id, :payment_method_id, :expense_type, :recurring_cycle, :renewal_month, :amount, :start_month, :end_month, :memo
      ])
    end

    def render_validation_error(expense)
      render json: { error: { code: "validation_error", message: "Invalid expense params", details: expense.errors } },
             status: :unprocessable_entity
    end
  end
end
