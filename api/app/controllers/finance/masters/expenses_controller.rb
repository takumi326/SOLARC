# frozen_string_literal: true

module Finance
  module Masters
    class ExpensesController < ApplicationController
      include FinanceMonthParams

      def new
        @expense = Expense.new(expense_type: params[:expense_type].presence_in(%w[one_time recurring]) || "one_time")
        load_form_options
      end

      def create
        @expense = Expense.new(expense_params)
        load_form_options
        if @expense.save
          if @expense.expense_type_one_time?
            MonthlyActualsSyncService.new(month: @expense.start_month, expense_scope: :one_time).call
          end
          redirect_to finance_masters_path(tab: "expenses", filter: @expense.expense_type), notice: "支出を追加しました。"
        else
          flash.now[:alert] = @expense.errors.full_messages.join(" ")
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        @expense = Expense.find(params[:id])
        load_form_options
      end

      def update
        @expense = Expense.find(params[:id])
        load_form_options
        if @expense.update(expense_params)
          redirect_to finance_masters_path(tab: "expenses", filter: @expense.expense_type), notice: "支出を更新しました。"
        else
          flash.now[:alert] = @expense.errors.full_messages.join(" ")
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        expense = Expense.find(params[:id])
        filter = expense.expense_type
        expense.destroy!
        redirect_to finance_masters_path(tab: "expenses", filter: filter), notice: "支出を削除しました。"
      end

      private

      def load_form_options
        @expense_minors = MinorCategory.joins(:major_category)
                                       .includes(:major_category)
                                       .where(major_categories: { kind: :expense })
                                       .order("major_categories.name ASC", "minor_categories.name ASC")
        @payment_methods = PaymentMethod.order(:name, :id)
      end

      def expense_params
        permitted = params.expect(expense: [
          :minor_category_id, :payment_method_id, :expense_type, :recurring_cycle,
          :renewal_month, :amount, :start_month, :end_month, :memo
        ])
        start_month = parse_month_param(permitted[:start_month])
        end_month = permitted[:end_month].present? ? parse_month_param(permitted[:end_month]) : nil
        permitted.to_h.symbolize_keys.merge(start_month: start_month, end_month: end_month)
      end
    end
  end
end
