# frozen_string_literal: true

# やることカードの外で、直近の完了を見返す履歴（平日向け）。
class DailyRoutineHistory
  HolidayRecord = Data.define(:watch_period_label, :completed_on, :starts_on, :ends_on)
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
    @holiday_records ||= begin
      visible_batches = recent_batches.select do |batch|
        watch_history_visible?(batch) && batch.stock_watch_items.any?
      end

      visible_batches
        .group_by { |batch| [ batch.starts_on, batch.ends_on ] }
        .map do |(starts_on, ends_on), batches|
          HolidayRecord.new(
            watch_period_label: batches.first.watch_period_label,
            completed_on: batches.map(&:imported_on).max,
            starts_on: starts_on,
            ends_on: ends_on
          )
        end
        .sort_by { |record| [ -record.completed_on.to_time.to_i, record.watch_period_label ] }
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

  # 監視期間が始まってから終わるまで（平日のみ）。未来の期間は出さない。
  def watch_history_visible?(batch)
    return false unless history_day?
    return false if batch.imported_on > @date
    return false if @date < batch.starts_on
    return false if @date > batch.ends_on

    true
  end

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
      .includes(:stock_watch_items)
      .where("imported_on >= ?", 60.days.ago.to_date)
      .recent
  end
end
