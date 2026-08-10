# frozen_string_literal: true

class FinanceExpenseImportParser
  ParsedRow = Struct.new(
    :line_number,
    :month_date,
    :month_label,
    :category_path,
    :amount,
    :memo,
    :minor_category_id,
    :source_id,
    keyword_init: true
  )

  class ParseError < StandardError; end

  def initialize(raw_json:, expense_minors:)
    @raw_json = raw_json
    @expense_minors = expense_minors
    @minor_by_id = expense_minors.index_by(&:id)
  end

  def call
    rows = JSON.parse(self.class.extract_json_payload(@raw_json))
    raise ParseError, "JSON配列で入力してください" unless rows.is_a?(Array)

    rows.map.with_index(1) { |row, line_number| parse_row(row, line_number) }
  rescue JSON::ParserError => e
    raise ParseError, "JSONの形式が不正です: #{e.message}"
  end

  def self.extract_json_payload(raw)
    text = raw.to_s.strip
    text = text.split("\n---\n", 2).first
    text = text.split("\n---", 2).first.to_s.strip
    if (match = text.match(/```(?:json)?\s*([\s\S]*?)```/m))
      text = match[1].strip
    end
    text
  end

  private

  def parse_row(row, line_number)
    raise ParseError, "各行はオブジェクトにしてください（#{line_number}行目）" unless row.is_a?(Hash)

    minor = resolve_minor(row, line_number)
    month_date = resolve_month_date(row, line_number)
    amount = resolve_amount(row, line_number)
    memo = resolve_memo(row, line_number)
    category_path = "#{minor.major_category.name} / #{minor.name}"

    ParsedRow.new(
      line_number: line_number,
      month_date: month_date,
      month_label: month_date.strftime("%Y-%m"),
      category_path: category_path,
      amount: amount,
      memo: memo,
      minor_category_id: minor.id,
      source_id: row["source_id"].to_s.strip.presence
    )
  end

  def resolve_minor(row, line_number)
    id_raw = row["minor_category_id"]
    if id_raw.present?
      id = Integer(id_raw)
      minor = @minor_by_id[id]
      raise ParseError, "#{line_number}行目: minor_category_id #{id} は支出の小カテゴリにありません" unless minor

      return minor
    end

    category = row["category"].to_s.strip
    if category.present?
      minor = find_minor_by_category_text(category)
      raise ParseError, "#{line_number}行目: category が見つかりません (#{category})" unless minor

      return minor
    end

    raise ParseError, "#{line_number}行目: minor_category_id（数値）が必要です"
  end

  def find_minor_by_category_text(text)
    key = text.strip
    @expense_minors.find { |m| "#{m.major_category.name} / #{m.name}" == key } ||
      @expense_minors.find { |m| m.name == key }
  end

  def resolve_month_date(row, line_number)
    if row["month"].present?
      yyyymm = parse_import_month_field(row["month"])
      raise ParseError, "#{line_number}行目: month（YYYY-MM または YYYY年MM月）が必要です" unless yyyymm

      return Date.parse("#{yyyymm}-01").beginning_of_month
    end

    if row["date"].present?
      return Date.parse(row["date"].to_s).beginning_of_month
    end

    if row["payment_date"].present?
      return Date.parse(row["payment_date"].to_s).beginning_of_month
    end

    raise ParseError, "#{line_number}行目: month または date（YYYY-MM-DD）が必要です"
  rescue Date::Error
    raise ParseError, "#{line_number}行目: month / date の日付が不正です"
  end

  def parse_import_month_field(raw)
    s = raw.to_s.strip
    return s.slice(0, 7) if s.match?(/\A\d{4}-\d{2}/)

    m = s.match(/\A(\d{4})年(\d{1,2})月/)
    return "#{m[1]}-#{format('%02d', m[2].to_i)}" if m

    nil
  end

  def resolve_amount(row, line_number)
    amount = row["amount"].to_d
    raise ParseError, "#{line_number}行目: amount は0以上の数値にしてください" unless amount.finite? && amount >= 0

    amount.round.to_i
  end

  def resolve_memo(row, line_number)
    raw = row["memo"]
    return nil if raw.blank?

    memo = raw.to_s.strip
    raise ParseError, "#{line_number}行目: memo は2000文字以内にしてください" if memo.length > 2000

    memo.presence
  end
end
