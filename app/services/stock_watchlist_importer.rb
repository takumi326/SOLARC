# frozen_string_literal: true

# TradingView 形式の監視リスト（TSE:コード,...）を複数ファイルまとめて取り込む。
class StockWatchlistImporter
  Result = Data.define(:batch, :imported_count, :missing_codes, :source_labels)

  def self.import!(files:, imported_on:, starts_on:, ends_on:)
    new(files:, imported_on:, starts_on:, ends_on:).import!
  end

  def initialize(files:, imported_on:, starts_on:, ends_on:)
    @files = Array(files).compact
    @imported_on = imported_on.to_date
    @starts_on = starts_on.to_date
    @ends_on = ends_on.to_date
  end

  def import!
    raise ArgumentError, "ファイルを1つ以上選んでください" if @files.empty?
    raise ArgumentError, "監視終了日は開始日以降にしてください" if @ends_on < @starts_on

    parsed = @files.flat_map { |file| parse_file(file) }
    raise ArgumentError, "銘柄コードが見つかりませんでした" if parsed.empty?

    codes = parsed.map { |row| row[:code] }.uniq
    stocks_by_code = Stock.where(code: codes).index_by(&:code)
    missing_codes = codes.reject { |code| stocks_by_code.key?(code) }
    rows = parsed.select { |row| stocks_by_code.key?(row[:code]) }
    raise ArgumentError, "登録済み銘柄がありません（未登録: #{missing_codes.join(', ')}）" if rows.empty?

    batch = nil
    ActiveRecord::Base.transaction do
      batch = StockWatchBatch.create!(
        imported_on: @imported_on,
        starts_on: @starts_on,
        ends_on: @ends_on
      )

      rows.group_by { |row| row[:code] }.each do |code, code_rows|
        labels = code_rows.map { |row| row[:source_label] }.uniq
        StockWatchItem.create!(
          stock_watch_batch: batch,
          stock: stocks_by_code.fetch(code),
          source_label: labels.join(" / ")
        )
      end

      StockWatchBatch.sync_watched_flags!
    end

    Result.new(
      batch: batch,
      imported_count: batch.stock_watch_items.count,
      missing_codes: missing_codes,
      source_labels: batch.source_labels
    )
  end

  def self.label_from_filename(filename)
    base = File.basename(filename.to_s, ".*")
    base = base.sub(/_[0-9a-f]{4,}\z/i, "")
    base.presence || "監視リスト"
  end

  private

  def parse_file(file)
    filename = file.respond_to?(:original_filename) ? file.original_filename : file.to_s
    label = self.class.label_from_filename(filename)
    content = read_content(file)

    content.split(/[,\s]+/).filter_map do |token|
      code = extract_code(token)
      next if code.blank?

      { code: code, source_label: label }
    end
  end

  def read_content(file)
    if file.respond_to?(:read)
      file.rewind if file.respond_to?(:rewind)
      file.read.to_s
    else
      File.read(file.to_s)
    end
  end

  def extract_code(token)
    text = token.to_s.strip
    return if text.blank?

    if (match = text.match(/\ATSE:(\d{3,5})\z/i))
      match[1]
    elsif text.match?(/\A\d{3,5}\z/)
      text
    end
  end
end
