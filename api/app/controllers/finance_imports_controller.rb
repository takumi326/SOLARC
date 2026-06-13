# frozen_string_literal: true

class FinanceImportsController < ApplicationController
  include FinanceMonthParams

  FIXED_PAYMENT_METHOD_NAME = FinanceImportClaudePromptBuilder::FIXED_PAYMENT_METHOD_NAME

  def show
    load_import_context
    if params[:reset].present?
      clear_import_session
      @phase = "edit"
      @raw_json = ""
    elsif session[:finance_import_phase] == "preview"
      @phase = "preview"
      load_preview_from_session
    else
      @phase = "edit"
      @raw_json = session[:finance_import_raw_json].to_s
    end
  end

  def create
    load_import_context
    @raw_json = params[:raw_json].to_s
    session[:finance_import_raw_json] = @raw_json

    begin
      @pending_rows = FinanceExpenseImportParser.new(raw_json: @raw_json, expense_minors: @expense_minors).call
      if @pending_rows.empty?
        flash.now[:alert] = "取り込む行がありません"
        @phase = "edit"
        return render :show, status: :unprocessable_entity
      end

      store_preview_session(@pending_rows)
      @compare_month_input = min_month_label(@pending_rows)
      @selected_line_numbers = @pending_rows.map(&:line_number)
      load_preview_tables
      @phase = "preview"
      session[:finance_import_phase] = "preview"
      render :show
    rescue FinanceExpenseImportParser::ParseError => e
      flash.now[:alert] = e.message
      @phase = "edit"
      render :show, status: :unprocessable_entity
    end
  end

  def commit
    load_import_context
    pending_rows = load_pending_rows_from_session
    if pending_rows.empty?
      redirect_to finance_import_path, alert: "プレビューが期限切れです。JSONを再度入力してください。"
      return
    end

    selected = Array(params[:line_numbers]).map(&:to_i)
    rows_to_import = pending_rows.select { |row| selected.include?(row.line_number) }
    if rows_to_import.empty?
      @phase = "preview"
      @pending_rows = pending_rows
      @compare_month_input = params[:compare_month].presence || min_month_label(pending_rows)
      @selected_line_numbers = selected
      load_preview_tables
      flash.now[:alert] = "取り込む行を1件以上選んでください"
      return render :show, status: :unprocessable_entity
    end

    unless @fixed_payment_method
      redirect_to finance_import_path, alert: "支払方法「#{FIXED_PAYMENT_METHOD_NAME}」がマスタにありません。"
      return
    end

    result = FinanceExpenseImportService.new(rows: rows_to_import, payment_method: @fixed_payment_method).call
    clear_import_session
    redirect_to finance_summary_path, notice: "#{result.imported_count}件を取り込みました。"
  rescue StandardError => e
    redirect_to finance_import_path, alert: e.message
  end

  private

  def load_import_context
    @expense_minors = MinorCategory.joins(:major_category)
                                   .includes(:major_category)
                                   .where(major_categories: { kind: :expense })
                                   .order("major_categories.name ASC", "minor_categories.name ASC")
    @fixed_payment_method = FinanceExpenseImportService.fixed_payment_method
    preference = UserPreference.find_or_initialize_by(owner_key: preference_owner_key)
    @import_prompt_draft = ImportPromptTemplate.draft_for(preference)
    @import_prompt_month = params[:prompt_month].presence || Date.current.strftime("%Y-%m")
    catalog = @expense_minors.map { |m| "- id #{m.id}: #{m.major_category.name} / #{m.name}" }.join("\n")
    @claude_prompt = FinanceImportClaudePromptBuilder.build(
      catalog: catalog,
      example_minor_id: @expense_minors.first&.id || 1,
      month: @import_prompt_month,
      saved_template: preference.import_claude_prompt_template
    )
  end

  def load_preview_from_session
    @pending_rows = load_pending_rows_from_session
    @compare_month_input = params[:compare_month].presence || session[:finance_import_compare_month].presence || min_month_label(@pending_rows)
    session[:finance_import_compare_month] = @compare_month_input
    @selected_line_numbers = Array(params[:line_numbers]).presence || session[:finance_import_selected_lines] || @pending_rows.map(&:line_number)
    load_preview_tables
  end

  def load_preview_tables
    compare_month = parse_month_param("#{@compare_month_input}-01")
    pending_for_month = @pending_rows.select { |row| row.month_label == @compare_month_input }
    @existing_rows = FinanceExpenseImportService.existing_one_time_rows(compare_month: compare_month, pending_rows: pending_for_month)
    @hidden_duplicate_count = pending_for_month.count do |pr|
      @existing_rows.any? { |er| er[:minor_category_id] == pr.minor_category_id && er[:amount] == pr.amount }
    end
    @right_table_rows = @pending_rows.reject do |row|
      row.month_label == @compare_month_input &&
        @existing_rows.any? { |er| er[:minor_category_id] == row.minor_category_id && er[:amount] == row.amount }
    end
  end

  def store_preview_session(rows)
    session[:finance_import_pending] = rows.map do |row|
      {
        "line_number" => row.line_number,
        "month_date" => row.month_date.to_s,
        "month_label" => row.month_label,
        "category_path" => row.category_path,
        "amount" => row.amount,
        "memo" => row.memo,
        "minor_category_id" => row.minor_category_id
      }
    end
    session[:finance_import_selected_lines] = rows.map(&:line_number)
    session[:finance_import_compare_month] = min_month_label(rows)
  end

  def load_pending_rows_from_session
    Array(session[:finance_import_pending]).map do |hash|
      FinanceExpenseImportParser::ParsedRow.new(
        line_number: hash["line_number"],
        month_date: Date.parse(hash["month_date"]),
        month_label: hash["month_label"],
        category_path: hash["category_path"],
        amount: hash["amount"],
        memo: hash["memo"],
        minor_category_id: hash["minor_category_id"]
      )
    end
  end

  def clear_import_session
    session.delete(:finance_import_phase)
    session.delete(:finance_import_raw_json)
    session.delete(:finance_import_pending)
    session.delete(:finance_import_selected_lines)
    session.delete(:finance_import_compare_month)
  end

  def min_month_label(rows)
    rows.map(&:month_label).min
  end
end
