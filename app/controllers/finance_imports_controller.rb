# frozen_string_literal: true

class FinanceImportsController < ApplicationController
  include FinanceMonthParams

  FIXED_PAYMENT_METHOD_NAME = FinanceImportClaudePromptBuilder::FIXED_PAYMENT_METHOD_NAME

  def show
    load_import_context
    draft = import_draft
    if params[:reset].present?
      clear_import_draft
      @phase = "edit"
      @raw_json = ""
    elsif draft.preview?
      @phase = "preview"
      load_preview_from_draft(draft)
    else
      @phase = "edit"
      @raw_json = draft.raw_json.to_s
    end
  end

  def create
    load_import_context
    @raw_json = params[:raw_json].to_s
    draft = import_draft

    begin
      @pending_rows = FinanceExpenseImportParser.new(raw_json: @raw_json, expense_minors: @expense_minors).call
      if @pending_rows.empty?
        persist_edit_draft(draft, @raw_json)
        flash.now[:alert] = "取り込む行がありません"
        @phase = "edit"
        return render :show, status: :unprocessable_entity
      end

      unless draft_storage_available?
        flash.now[:alert] = draft_storage_unavailable_message
        @phase = "edit"
        return render :show, status: :service_unavailable
      end

      store_preview_draft(draft, @pending_rows, raw_json: @raw_json)
      @compare_month_input = min_month_label(@pending_rows)
      @selected_line_numbers = @pending_rows.map(&:line_number)
      @verification_text = FinanceImportPreviewSummary.verification_text(@raw_json)
      load_preview_tables
      @phase = "preview"
      render :show
    rescue FinanceExpenseImportParser::ParseError => e
      persist_edit_draft(draft, @raw_json)
      flash.now[:alert] = e.message
      @phase = "edit"
      render :show, status: :unprocessable_entity
    end
  end

  def commit
    load_import_context
    draft = import_draft
    pending_rows = load_pending_rows_from_draft(draft)
    if pending_rows.empty?
      redirect_to finance_import_path, alert: "プレビューが期限切れです。JSONを再度入力してください。"
      return
    end

    pending_rows = apply_row_overrides(pending_rows, params[:rows])
    persist_pending_rows(draft, pending_rows)

    selected = Array(params[:line_numbers]).map(&:to_i)
    rows_to_import = pending_rows.select { |row| selected.include?(row.line_number) }
    if rows_to_import.empty?
      @phase = "preview"
      @pending_rows = pending_rows
      @compare_month_input = params[:compare_month].presence || draft.compare_month.presence || min_month_label(pending_rows)
      @selected_line_numbers = selected
      @verification_text = FinanceImportPreviewSummary.verification_text(draft.raw_json)
      load_preview_tables
      flash.now[:alert] = "取り込む行を1件以上選んでください"
      return render :show, status: :unprocessable_entity
    end

    unless @fixed_payment_method
      redirect_to finance_import_path, alert: "支払方法「#{FIXED_PAYMENT_METHOD_NAME}」がマスタにありません。"
      return
    end

    result = FinanceExpenseImportService.new(rows: rows_to_import, payment_method: @fixed_payment_method).call
    clear_import_draft
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
      saved_template: preference.import_claude_prompt_template,
      merchant_rules: ImportPromptTemplate.merchant_rules_for(preference)
    )
  end

  def import_draft
    return @import_draft if @import_draft

    @import_draft = if draft_storage_available?
      FinanceImportDraft.find_or_initialize_by(owner_key: preference_owner_key)
    else
      FinanceImportDraft.in_memory_for(preference_owner_key)
    end
  end

  def load_preview_from_draft(draft)
    @pending_rows = load_pending_rows_from_draft(draft)
    @compare_month_input = params[:compare_month].presence || draft.compare_month.presence || min_month_label(@pending_rows)
    if draft.compare_month != @compare_month_input && draft.persisted?
      draft.update!(compare_month: @compare_month_input)
    end
    @selected_line_numbers = Array(params[:line_numbers]).presence || draft.selected_lines.presence || @pending_rows.map(&:line_number)
    @verification_text = FinanceImportPreviewSummary.verification_text(draft.raw_json)
    load_preview_tables
  end

  def load_preview_tables
    compare_month = parse_month_param("#{@compare_month_input}-01")
    pending_for_month = @pending_rows.select { |row| row.month_label == @compare_month_input }
    @existing_rows = FinanceExpenseImportService.existing_one_time_rows(compare_month: compare_month, pending_rows: pending_for_month)
    @duplicate_pairs = FinanceImportPreviewSummary.duplicate_pairs(pending_for_month, @existing_rows)
    @duplicate_pending_rows = @duplicate_pairs.map(&:pending)
    duplicate_line_numbers = @duplicate_pending_rows.map(&:line_number).to_set
    @right_table_rows = @pending_rows.reject { |row| duplicate_line_numbers.include?(row.line_number) }
    pending_line_by_existing_id = @duplicate_pairs.to_h { |pair| [ pair.existing[:id], pair.pending.line_number ] }
    @existing_rows.each do |row|
      row[:pending_line_number] = pending_line_by_existing_id[row[:id]]
    end
    @import_summary = FinanceImportPreviewSummary.build(
      pending_rows: @pending_rows,
      duplicate_rows: @duplicate_pending_rows,
      compare_month: @compare_month_input
    )
  end

  def persist_edit_draft(draft, raw_json)
    draft.assign_attributes(phase: "edit", raw_json: raw_json, pending_rows: [], selected_lines: [], compare_month: nil)
    return unless draft_storage_available?

    draft.save!
  end

  def store_preview_draft(draft, rows, raw_json:)
    draft.update!(
      phase: "preview",
      raw_json: raw_json,
      pending_rows: serialize_rows(rows),
      selected_lines: rows.map(&:line_number),
      compare_month: min_month_label(rows)
    )
  end

  def serialize_rows(rows)
    rows.map do |row|
      {
        "line_number" => row.line_number,
        "month_date" => row.month_date.to_s,
        "month_label" => row.month_label,
        "category_path" => row.category_path,
        "amount" => row.amount,
        "memo" => row.memo,
        "minor_category_id" => row.minor_category_id,
        "source_id" => row.source_id
      }
    end
  end

  def load_pending_rows_from_draft(draft)
    minor_by_id = @expense_minors.index_by(&:id)
    Array(draft.pending_rows).filter_map do |hash|
      minor = minor_by_id[hash["minor_category_id"]]
      next unless minor

      month_date = Date.parse(hash["month_date"])
      FinanceExpenseImportParser::ParsedRow.new(
        line_number: hash["line_number"],
        month_date: month_date,
        month_label: hash["month_label"].presence || month_date.strftime("%Y-%m"),
        category_path: hash["category_path"].presence || "#{minor.major_category.name} / #{minor.name}",
        amount: hash["amount"],
        memo: hash["memo"],
        minor_category_id: hash["minor_category_id"],
        source_id: hash["source_id"]
      )
    end
  end

  def clear_import_draft
    return unless draft_storage_available?

    FinanceImportDraft.find_by(owner_key: preference_owner_key)&.destroy
    @import_draft = nil
  end

  def draft_storage_available?
    FinanceImportDraft.storage_available?
  end

  def draft_storage_unavailable_message
    "取込機能の DB 更新が未完了です。Render のデプロイ完了後、数分待ってから再度お試しください。"
  end

  def min_month_label(rows)
    rows.map(&:month_label).min
  end

  def apply_row_overrides(rows, row_params)
    return rows if row_params.blank?

    minor_by_id = @expense_minors.index_by(&:id)
    rows.map do |row|
      overrides = row_params[row.line_number.to_s]
      next row unless overrides

      if overrides[:minor_category_id].present?
        minor = minor_by_id[overrides[:minor_category_id].to_i]
        raise ArgumentError, "カテゴリが不正です（行 #{row.line_number}）" unless minor

        row.minor_category_id = minor.id
        row.category_path = "#{minor.major_category.name} / #{minor.name}"
      end

      if overrides.key?(:memo)
        memo = overrides[:memo].to_s.strip
        raise ArgumentError, "メモは2000文字以内にしてください（行 #{row.line_number}）" if memo.length > 2000

        row.memo = memo.presence
      end

      row
    end
  end

  def persist_pending_rows(draft, rows)
    return unless draft_storage_available? && draft.persisted?

    draft.update!(pending_rows: serialize_rows(rows))
  end
end
