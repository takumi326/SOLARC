# frozen_string_literal: true

require "csv"

# JPX日経400構成銘柄ウェイト一覧 CSV 想定:
# - 公式: Shift_JIS、列 日付, 銘柄名, コード, 業種, …
# - スプレッドシート等: UTF-8、列 銘柄名, コード, 業種 でも可
class StockCsvImporter
  Result = Struct.new(:created_industries, :updated_stocks, :created_stocks, :skipped_rows, keyword_init: true)

  def self.import!(io)
    new(io).import!
  end

  def initialize(io)
    @io = io
  end

  def import!
    text = read_utf8(io_content)
    created_industries = 0
    created_stocks = 0
    updated_stocks = 0
    skipped_rows = 0

    rows = CSV.parse(text, headers: true)
    rows.each do |row|
      industry_name = cell(row, "業種").presence || col_by_index(row, 3)
      name = cell(row, "銘柄名").presence || col_by_index(row, 1)
      code_raw = cell(row, "コード").presence || col_by_index(row, 2)

      if industry_name.blank?
        skipped_rows += 1
        next
      end

      code = normalize_code(code_raw)
      if code.blank? || name.blank?
        skipped_rows += 1
        next
      end

      industry = Industry.find_by(name: industry_name.strip)
      unless industry
        industry = Industry.create!(name: industry_name.strip)
        created_industries += 1
      end

      stock = Stock.find_by(code: code)
      if stock
        if stock.update(name: name.strip, industry_id: industry.id)
          updated_stocks += 1
        end
      else
        Stock.create!(code: code, name: name.strip, industry_id: industry.id)
        created_stocks += 1
      end
    end

    Result.new(
      created_industries: created_industries,
      updated_stocks: updated_stocks,
      created_stocks: created_stocks,
      skipped_rows: skipped_rows
    )
  end

  private

  def io_content
    @io.is_a?(String) ? @io : @io.read
  end

  def read_utf8(raw)
    binary = raw.dup.force_encoding("BINARY")
    binary = binary.byteslice(3..) if binary.start_with?("\xEF\xBB\xBF".b)

    utf8 = binary.dup.force_encoding("UTF-8")
    return utf8 if utf8.valid_encoding?

    binary.encode("UTF-8", "CP932", invalid: :replace, undef: :replace)
  end

  def cell(row, header)
    v = row[header]
    v = row[header.encode("UTF-8")] if v.nil? && header.is_a?(String)
    v.to_s.strip
  end

  def col_by_index(row, idx)
    row.is_a?(CSV::Row) ? row[idx]&.to_s&.strip : nil
  end

  def normalize_code(raw)
    s = raw.to_s.gsub(/\s+/, "")
    return "" if s.blank?
    return s.rjust(4, "0") if s.match?(/\A\d{1,4}\z/)

    s
  end
end
