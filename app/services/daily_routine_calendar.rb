# frozen_string_literal: true

class DailyRoutineCalendar
  DayCell = Data.define(:date, :in_month, :selected, :today, :status, :off_day)
  MonthView = Data.define(:month, :weeks, :prev_month, :next_month)

  def initialize(owner_key:, month:, selected_date:, preference: nil)
    @owner_key = owner_key
    @month = month.to_date.beginning_of_month
    @selected_date = selected_date.to_date
    @preference = preference
  end

  def call
    range = @month..@month.end_of_month
    padded = (range.begin - 14)..(range.end + 14)
    notes = StockDailyNote.where(owner_key: @owner_key, recorded_on: padded).index_by(&:recorded_on)
    extra_off = DailyRoutineOffDay.for_owner(@owner_key).covering(padded).pluck(:off_on).to_set
    classifier = DailyRoutineDayClassifier.new(owner_key: @owner_key, extra_off_dates: extra_off)

    imported_months = DailyRoutineStatus.imported_months_for(tracked_months)

    import_dates = StockWatchBatch
      .where(imported_on: padded)
      .pluck(:imported_on)
      .to_set
    watched_dates = watched_dates_in(padded)

    grid_start = @month.beginning_of_week(:sunday)
    grid_end = @month.end_of_month.end_of_week(:sunday)
    days = (grid_start..grid_end).to_a

    weeks = days.each_slice(7).map do |week_days|
      week_days.map do |cell_date|
        in_month = cell_date.month == @month.month
        off = classifier.off_day?(cell_date)
        status =
          if in_month
            period = classifier.off_period(cell_date)
            watchlist_imported =
              if period
                period.any? { |d| import_dates.include?(d) }
              else
                false
              end

            DailyRoutineStatus.new(
              owner_key: @owner_key,
              date: cell_date,
              note: notes[cell_date],
              classifier: classifier,
              watchlist_imported_in_period: watchlist_imported,
              imported_months: imported_months,
              preference: preference,
              has_watched_stocks: watched_dates.include?(cell_date)
            ).day_status
          else
            :outside
          end

        DayCell.new(
          date: cell_date,
          in_month: in_month,
          selected: cell_date == @selected_date,
          today: cell_date == Date.current,
          status: status,
          off_day: off
        )
      end
    end

    MonthView.new(
      month: @month,
      weeks: weeks,
      prev_month: @month.prev_month,
      next_month: @month.next_month
    )
  end

  private

  def preference
    @preference ||= UserPreference.find_or_initialize_by(owner_key: @owner_key)
  end

  def watched_dates_in(range)
    dates = Set.new
    StockWatchBatch.joins(:stock_watch_items)
      .overlapping(range.begin, range.end)
      .distinct
      .pluck(:starts_on, :ends_on)
      .each do |starts_on, ends_on|
        from = [ starts_on, range.begin ].max
        to = [ ends_on, range.end ].min
        next if from > to

        (from..to).each { |day| dates.add(day) }
      end
    dates
  end

  # 表示月のセルが参照しうる「終わった月」をまとめて引く
  def tracked_months
    months = []
    month = DailyRoutineStatus::TRACKING_START_MONTH
    while month <= @month
      months << month
      month = month.next_month
    end
    months
  end
end
