module Api
  class IncomesController < ApplicationController
    before_action :set_income, only: [ :update, :destroy, :actuals, :bulk_update_actuals_from_month, :update_actual, :destroy_actual ]
    before_action :ensure_income!, only: [ :update, :destroy, :actuals, :bulk_update_actuals_from_month, :update_actual, :destroy_actual ]

    def index
      incomes = Income.joins(:minor_category)
                      .preload(:minor_category)
                      .order(Arel.sql("minor_categories.name ASC, incomes.id ASC"))
      render json: { data: incomes.map { |i| income_json(i) } }
    end

    def create
      income = Income.new(income_params)
      if income.save
        render json: { data: income_json(income) }, status: :created
      else
        render_validation_error(income)
      end
    end

    def update
      if @income.update(income_params)
        render json: { data: income_json(@income) }
      else
        render_validation_error(@income)
      end
    end

    def destroy
      @income.destroy!
      head :no_content
    end

    def actuals
      rows = @income.income_transactions
                    .joins(:ledger_transaction)
                    .includes(:ledger_transaction)
                    .order(Arel.sql("transactions.month ASC, income_transactions.id ASC"))
      render json: {
        data: rows.map { |row| income_actual_row_json(row.ledger_transaction) }
      }
    end

    def bulk_update_actuals_from_month
      unless @income.income_type_recurring?
        return render json: {
          error: { code: "bad_request", message: "定期の収入のみ一括変更できます" }
        }, status: :unprocessable_entity
      end

      attrs = bulk_actual_params
      result = BulkUpdateMasterActualsFromMonthService.call(
        master: @income,
        from_month: attrs[:from_month],
        amount: attrs[:amount],
        negative: false
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
      it = @income.income_transactions.find_by(transaction_id: tx_id)
      unless it
        render json: { error: { code: "not_found", message: "この収入に紐づく実績取引が見つかりません" } }, status: :not_found
        return
      end

      attrs = income_actual_ledger_params
      tx = it.ledger_transaction
      new_month = attrs[:month].present? ? Date.parse(attrs[:month]).beginning_of_month : tx.month
      new_amount = attrs[:amount].present? ? attrs[:amount].to_d.abs : tx.amount

      if duplicate_income_ledger_month?(income: @income, month: new_month, except_transaction_id: tx.id)
        render json: {
          error: { code: "duplicate_month", message: "同じ月に別の実績が既にあります" }
        }, status: :unprocessable_entity
        return
      end

      tx.month = new_month
      tx.amount = new_amount
      if tx.save
        render json: { data: income_actual_row_json(tx) }
      else
        render json: {
          error: { code: "validation_error", message: "実績の更新に失敗しました", details: tx.errors }
        }, status: :unprocessable_entity
      end
    rescue ArgumentError, TypeError
      render json: { error: { code: "bad_request", message: "transaction_id または日付・金額が不正です" } }, status: :bad_request
    end

    def destroy_actual
      tx_id = Integer(params[:transaction_id])
      it = @income.income_transactions.find_by(transaction_id: tx_id)
      unless it
        render json: { error: { code: "not_found", message: "この収入に紐づく実績取引が見つかりません" } }, status: :not_found
        return
      end

      it.ledger_transaction.destroy!
      head :no_content
    rescue ArgumentError, TypeError
      render json: { error: { code: "bad_request", message: "transaction_id が不正です" } }, status: :bad_request
    end

    private

    def income_actual_row_json(tx)
      {
        transaction_id: tx.id,
        month: tx.month,
        amount: tx.amount
      }
    end

    def income_actual_ledger_params
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

    def duplicate_income_ledger_month?(income:, month:, except_transaction_id:)
      income.income_transactions
            .joins(:ledger_transaction)
            .where.not(transaction_id: except_transaction_id)
            .exists?(transactions: { month: month })
    end

    def set_income
      @income = Income.find_by(id: params[:id])
    end

    def ensure_income!
      return if @income.present?

      render json: { error: { code: "not_found", message: "Income not found" } }, status: :not_found
    end

    def income_params
      params.expect(income: [ :minor_category_id, :income_type, :amount, :start_month, :end_month ])
    end

    def income_json(income)
      income.as_json(only: [ :id, :minor_category_id, :income_type, :amount, :start_month, :end_month ])
    end

    def render_validation_error(income)
      render json: { error: { code: "validation_error", message: "Invalid income params", details: income.errors } },
             status: :unprocessable_entity
    end
  end
end
