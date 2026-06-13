# frozen_string_literal: true

module Finance
  class OneTimeExpensesController < ApplicationController
    include FinanceMonthParams

    def new
      @month_input = params[:month].presence || month_input_value(Date.current)
      @expense = Expense.new(start_month: parse_month_param("#{@month_input}-01"))
      load_form_options
    end

    def create
      @expense = Expense.new(expense_params)
      @month_input = month_input_value(@expense.start_month || Date.current)
      load_form_options

      if @expense.save
        MonthlyActualsSyncService.new(month: @expense.start_month, expense_scope: :one_time).call
        redirect_to finance_summary_path(month: @month_input), notice: "単発の支出を追加しました。"
      else
        flash.now[:alert] = @expense.errors.full_messages.join(" ")
        render :new, status: :unprocessable_entity
      end
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
      permitted = params.expect(expense: [ :minor_category_id, :payment_method_id, :amount, :start_month, :memo ])
      month = parse_month_param(permitted[:start_month])
      {
        minor_category_id: permitted[:minor_category_id],
        payment_method_id: permitted[:payment_method_id],
        expense_type: :one_time,
        recurring_cycle: :monthly,
        renewal_month: nil,
        amount: permitted[:amount],
        start_month: month,
        end_month: month,
        memo: permitted[:memo]
      }
    end
  end
end
