# frozen_string_literal: true

class FinanceSummariesController < ApplicationController
  include FinanceMonthParams

  before_action :set_month, only: [ :show, :sync_recurring, :sync_one_time, :expense_breakdown, :monthly_balance ]

  def show
    load_summary_data
  end

  def sync_recurring
    months = fiscal_month_starts(@month)
    months.each { |m| MonthlyActualsSyncService.new(month: m, expense_scope: :recurring).call }
    redirect_to finance_summary_path(month: month_input_value(@month)), notice: "定期実績を作成しました。"
  rescue StandardError => e
    redirect_to finance_summary_path(month: month_input_value(@month)), alert: e.message
  end

  def sync_one_time
    MonthlyActualsSyncService.new(month: @month, expense_scope: :one_time).call
    redirect_to finance_summary_path(month: month_input_value(@month)), notice: "単発実績を同期しました。"
  rescue StandardError => e
    redirect_to finance_summary_path(month: month_input_value(@month)), alert: e.message
  end

  def expense_breakdown
    @view = params[:view].presence_in(%w[payment category lines]) || "payment"
    @dashboard = DashboardSummaryBuilder.new(month: @month).call
    @year_summary = FinanceYearSummaryBuilder.new(anchor_month: @month).call
    @expense_mode = @year_summary.selected_row&.expense&.mode || "予"
  end

  def edit_forecast
    @kind = "expense"
    @month = parse_month_param(params[:month])
    @forecast = Forecast.find_or_initialize_by(kind: @kind, month: @month)
    @return_month = month_input_value(@month)
  end

  def update_forecast
    @kind = "expense"
    @month = parse_month_param(params.dig(:forecast, :month))
    amount = params.dig(:forecast, :amount).to_d
    if !amount.finite? || amount.negative?
      @forecast = Forecast.find_or_initialize_by(kind: @kind, month: @month)
      @return_month = month_input_value(@month)
      flash.now[:alert] = "0以上の数値を入力してください"
      return render :edit_forecast, status: :unprocessable_entity
    end

    forecast = Forecast.find_or_initialize_by(kind: @kind, month: @month)
    forecast.amount = amount.round
    if forecast.save
      redirect_to finance_summary_path(month: month_input_value(@month)), notice: "予測を保存しました。"
    else
      @forecast = forecast
      @return_month = month_input_value(@month)
      flash.now[:alert] = forecast.errors.full_messages.join(" ")
      render :edit_forecast, status: :unprocessable_entity
    end
  end

  def bulk_forecasts_form
    @anchor_month = parse_month_param(params[:month])
    @fiscal_months = fiscal_month_starts(@anchor_month)
    @forecasts = Forecast.where(month: @fiscal_months).index_by { |f| [ f.kind, f.month ] }
    render :bulk_forecasts
  end

  def bulk_forecasts
    anchor = parse_month_param(params[:anchor_month])
    fiscal_months = fiscal_month_starts(anchor)
    rows_by_index = params.fetch(:rows, {})

    ActiveRecord::Base.transaction do
      fiscal_months.each_with_index do |month, idx|
        row = rows_by_index[idx.to_s] || rows_by_index[idx]
        next if row.blank?

        %w[expense].each do |kind|
          amount = row[kind].to_d
          raise ArgumentError, "金額は0以上で入力してください" unless amount.finite? && amount >= 0

          forecast = Forecast.find_or_initialize_by(kind: kind, month: month)
          forecast.amount = amount.round
          forecast.save!
        end
      end
    end

    redirect_to finance_summary_path(month: month_input_value(anchor)), notice: "予測をまとめて保存しました。"
  rescue StandardError => e
    @anchor_month = anchor
    @fiscal_months = fiscal_month_starts(anchor)
    @forecasts = Forecast.where(month: @fiscal_months).index_by { |f| [ f.kind, f.month ] }
    flash.now[:alert] = e.message
    render :bulk_forecasts, status: :unprocessable_entity
  end

  def monthly_balance
    amount = params.dig(:monthly_balance, :amount).to_d
    balance_month = parse_month_param(params.dig(:monthly_balance, :month) || params[:month])
    if !amount.finite? || amount.negative?
      redirect_to finance_summary_path(month: month_input_value(balance_month)), alert: "月末残高は0以上の数字で入力してください"
      return
    end

    balance = MonthlyBalance.find_or_initialize_by(month: balance_month)
    balance.amount = amount.round
    if balance.save
      redirect_to finance_summary_path(month: month_input_value(balance_month)), notice: "月末残高を保存しました。"
    else
      redirect_to finance_summary_path(month: month_input_value(balance_month)), alert: balance.errors.full_messages.join(" ")
    end
  end

  private

  include FiscalYearMonths

  def set_month
    @month = parse_month_param(params[:month])
    @month_input = month_input_value(@month)
  end

  def load_summary_data
    @year_summary = FinanceYearSummaryBuilder.new(anchor_month: @month).call
    @dashboard = DashboardSummaryBuilder.new(month: @month).call
    @month_end_balance = @dashboard[:monthly_balance]
    @month_end_form_month = params[:month_end].presence || @month_input
    month_end_month = parse_month_param("#{@month_end_form_month}-01")
    @month_end_dashboard =
      if month_end_month == @month.beginning_of_month
        @dashboard
      else
        DashboardSummaryBuilder.new(month: month_end_month).call
      end
  end
end
