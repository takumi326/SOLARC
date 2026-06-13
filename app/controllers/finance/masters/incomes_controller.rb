# frozen_string_literal: true

module Finance
  module Masters
    class IncomesController < ApplicationController
      include FinanceMonthParams

      def new
        @income = Income.new(income_type: preview_income_type || "one_time")
        load_form_options
      end

      def create
        @income = Income.new(income_params)
        load_form_options
        if @income.save
          sync_one_time_actuals(@income)
          redirect_to finance_masters_path(tab: "incomes", filter: @income.income_type), notice: "収入を追加しました。"
        else
          flash.now[:alert] = @income.errors.full_messages.join(" ")
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        @income = Income.find(params[:id])
        apply_income_type_preview(@income)
        load_form_options
      end

      def update
        @income = Income.find(params[:id])
        previous_start_month = @income.start_month
        load_form_options
        if @income.update(income_params)
          sync_one_time_actuals(@income, also_for_month: previous_start_month)
          redirect_to finance_masters_path(tab: "incomes", filter: @income.income_type), notice: "収入を更新しました。"
        else
          flash.now[:alert] = @income.errors.full_messages.join(" ")
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        income = Income.find(params[:id])
        filter = income.income_type
        income.destroy!
        redirect_to finance_masters_path(tab: "incomes", filter: filter), notice: "収入を削除しました。"
      end

      private

      def preview_income_type
        params[:income_type].presence_in(%w[one_time recurring])
      end

      def apply_income_type_preview(income)
        preview = preview_income_type
        income.income_type = preview if preview
      end

      def sync_one_time_actuals(income, also_for_month: nil)
        return unless income.income_type_one_time?

        [ income.start_month, also_for_month ].compact.uniq.each do |month|
          MonthlyActualsSyncService.new(month: month, expense_scope: :one_time).call
        end
      end

      def load_form_options
        @income_minors = MinorCategory.joins(:major_category)
                                      .includes(:major_category)
                                      .where(major_categories: { kind: :income })
                                      .order("major_categories.name ASC", "minor_categories.name ASC")
      end

      def income_params
        permitted = params.expect(income: [ :minor_category_id, :income_type, :amount, :start_month, :end_month ])
        start_month = parse_month_param(permitted[:start_month])
        end_month = permitted[:end_month].present? ? parse_month_param(permitted[:end_month]) : nil
        permitted.to_h.symbolize_keys.merge(start_month: start_month, end_month: end_month)
      end
    end
  end
end
