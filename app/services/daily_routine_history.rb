# frozen_string_literal: true

# やることカードの外で、直近の完了を見返す履歴（平日向け）。
class DailyRoutineHistory
  HolidayRecord = Data.define(:watch_period_label, :completed_on, :stocks, :source_labels)
  MonthRecord = Data.define(:month, :label, :imported_on)

  def initialize(owner_key:, date:, classifier:, status:)
    @owner_key = owner_key
    @date = date
    @classifier = classifier
    @status = status
  end

  def visible?
    history_day? && (holiday_records.any? || month_records.any?)
  end

  def holiday_records
    @holiday_records ||= recent_batches.filter_map do |batch|
      next unless history_window?(batch.imported_on)

      stocks = batch.stocks.includes(:industry).ordered
      next if stocks.empty?

      HolidayRecord.new(
        watch_period_label: batch.watch_period_label,
        completed_on: batch.imported_on,
        stocks: stocks,
        source_labels: batch.source_labels
      )
    end
  end

  def month_records
    @month_records ||= candidate_months.filter_map do |month|
      imported_on = @status.imported_on(month)
      next unless imported_on
      next if @status.month_end_todo?(month)
      next unless month_history_visible?(month, imported_on)

      MonthRecord.new(
        month: month,
        label: "#{month.strftime('%-m月')}末",
        imported_on: imported_on
      )
    end
  end

  private

  def history_day?
    !@classifier.weekend?(@date)
  end

  def candidate_months
    current = @date.beginning_of_month
    [ current.prev_month, current ].select { |month| month >= DailyRoutineStatus::TRACKING_START_MONTH }
  end

  def month_history_visible?(month, imported_on)
    current = @date.beginning_of_month
    return previous_month_history_window?(imported_on) if month == current.prev_month

    history_window?(imported_on)
  end

  def previous_month_history_window?(imported_on)
    return false unless history_day?
    return false if @date < imported_on

    @date <= imported_on + 6.days
  end

  # 完了日（取込日）〜その週の金曜。土日以外（有給の平日も含む）
  def history_window?(completed_on)
    return false unless history_day?
    return false if @date < completed_on

    @date <= history_end_date(completed_on)
  end

  def history_end_date(completed_on)
    if completed_on.friday?
      completed_on
    elsif completed_on.saturday? || completed_on.sunday?
      completed_on.next_occurring(:friday)
    else
      completed_on.beginning_of_week(:monday) + 4.days
    end
  end

  def recent_batches
    StockWatchBatch
      .includes(stock_watch_items: :stock)
      .where("imported_on >= ?", 60.days.ago.to_date)
      .recent
  end
end
