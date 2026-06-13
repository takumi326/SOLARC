# frozen_string_literal: true

module Finance
  module Masters
    class ExpensesController < ApplicationController
      include FinanceMonthParams

      def new
        @expense = Expense.new(expense_type: preview_expense_type || "one_time")
        load_form_options
      end

      def create
        @expense = Expense.new(expense_params)
        load_form_options
        if @expense.save
          sync_one_time_actuals(@expense)
          redirect_to finance_masters_path(tab: "expenses", filter: @expense.expense_type), notice: "支出を追加しました。"
        else
          flash.now[:alert] = @expense.errors.full_messages.join(" ")
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        @expense = Expense.find(params[:id])
        apply_expense_type_preview(@expense)
        load_form_options
      end

      def update
        @expense = Expense.find(params[:id])
        previous_start_month = @expense.start_month
        load_form_options
        if @expense.update(expense_params)
          sync_one_time_actuals(@expense, also_for_month: previous_start_month)
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

      def preview_expense_type
        params[:expense_type].presence_in(%w[one_time recurring])
      end

      def apply_expense_type_preview(expense)
        preview = preview_expense_type
        expense.expense_type = preview if preview
      end

      def sync_one_time_actuals(expense, also_for_month: nil)
        return unless expense.expense_type_one_time?

        [ expense.start_month, also_for_month ].compact.uniq.each do |month|
          MonthlyActualsSyncService.new(month: month, expense_scope: :one_time).call
        end
      end

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
