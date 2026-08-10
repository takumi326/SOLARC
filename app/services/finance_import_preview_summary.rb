# frozen_string_literal: true

class FinanceImportPreviewSummary
  Summary = Struct.new(
    :total_count,
    :total_amount,
    :importable_count,
    :importable_amount,
    :duplicate_count,
    :duplicate_amount,
    :needs_review_count,
    :by_month,
    :by_source,
    :by_card,
    keyword_init: true
  )

  DuplicatePair = Struct.new(:pending, :existing, keyword_init: true)
  FinalRow = Struct.new(
    :kind, :month_label, :category_path, :amount, :memo, :label, :card_name,
    keyword_init: true
  )

  def self.build_final_preview(existing_rows:, pending_rows:, duplicate_line_numbers:, selected_line_numbers:, compare_month:)
    rows = existing_rows.map do |row|
      FinalRow.new(
        kind: :existing,
        month_label: row[:month_label],
        category_path: row[:category_path],
        amount: row[:amount],
        memo: row[:memo],
        card_name: row[:card_name],
        label: row[:pending_line_number].present? ? "すでに保存済み（No.#{row[:pending_line_number]} と重複）" : "すでに保存済み"
      )
    end

    pending_rows.each do |row|
      next unless row.month_label == compare_month
      next if duplicate_line_numbers.include?(row.line_number)
      next unless selected_line_numbers.include?(row.line_number)

      rows << FinalRow.new(
        kind: :new,
        month_label: row.month_label,
        category_path: row.category_path,
        amount: row.amount,
        memo: row.memo,
        card_name: row.card_name,
        label: "これから保存（No.#{row.line_number}）"
      )
    end

    rows.sort_by { |row| [ row.category_path, row.amount, row.kind == :new ? 1 : 0, row.label ] }
  end

  def self.verification_text(raw_json)
    parts = raw_json.to_s.split(/\n---\n?/, 2)
    return nil if parts.size < 2

    parts[1].strip.presence
  end

  def self.duplicate_line_numbers(pending_rows, compare_month, existing_rows)
    pending_for_month = pending_rows.select { |row| row.month_label == compare_month }
    duplicate_pairs(pending_for_month, existing_rows).map { |pair| pair.pending.line_number }.to_set
  end

  def self.build(pending_rows:, duplicate_rows:, compare_month:)
    duplicate_lines = duplicate_rows.map(&:line_number).to_set
    importable = pending_rows.reject { |row| duplicate_lines.include?(row.line_number) }

    Summary.new(
      total_count: pending_rows.size,
      total_amount: pending_rows.sum(&:amount),
      importable_count: importable.size,
      importable_amount: importable.sum(&:amount),
      duplicate_count: duplicate_rows.size,
      duplicate_amount: duplicate_rows.sum(&:amount),
      needs_review_count: pending_rows.count { |row| row.memo.to_s.start_with?("要確認:") },
      by_month: month_breakdown(pending_rows),
      by_source: source_breakdown(pending_rows),
      by_card: card_breakdown(pending_rows)
    )
  end

  def self.duplicate_pairs(pending_for_month, existing_rows)
    pending_for_month.filter_map do |pending|
      existing = existing_rows.find do |row|
        row[:minor_category_id] == pending.minor_category_id &&
          row[:amount] == pending.amount &&
          row[:payment_method_id] == pending.payment_method_id
      end
      next unless existing

      DuplicatePair.new(pending: pending, existing: existing)
    end
  end

  def self.classify_source(source_id)
    return :unknown if source_id.blank?

    sid = source_id.to_s.strip
    return :paypal if sid.match?(/[A-Z]/) && sid.match?(/\A[A-Z0-9]{10,22}\z/)
    return :vpass if sid.match?(/\A[a-f0-9]{10,}\z/i)

    :unknown
  end

  def self.month_breakdown(rows)
    rows.group_by(&:month_label).sort.map do |month, group|
      [ month, { count: group.size, amount: group.sum(&:amount) } ]
    end.to_h
  end

  def self.source_breakdown(rows)
    groups = rows.group_by { |row| classify_source(row.source_id) }
    {
      vpass: tally_group(groups[:vpass]),
      paypal: tally_group(groups[:paypal]),
      unknown: tally_group(groups[:unknown])
    }
  end

  def self.card_breakdown(rows)
    rows.group_by(&:card_name).sort.map do |card_name, group|
      [ card_name, { count: group.size, amount: group.sum(&:amount) } ]
    end.to_h
  end

  def self.tally_group(rows)
    list = Array(rows)
    { count: list.size, amount: list.sum(&:amount) }
  end

  private_class_method :month_breakdown, :source_breakdown, :card_breakdown, :tally_group
end
