# frozen_string_literal: true

class DailyRoutineCalendar
  DayCell = Data.define(:date, :in_month, :selected, :today, :status, :off_day)
  MonthView = Data.define(:month, :weeks, :prev_month, :next_month)

  def initialize(owner_key:, month:, selected_date:)
    @owner_key = owner_key
    @month = month.to_date.beginning_of_month
    @selected_date = selected_date.to_date
  end

  def call
    range = @month..@month.end_of_month
    padded = (range.begin - 14)..(range.end + 14)
    notes = StockDailyNote.where(owner_key: @owner_key, recorded_on: padded).index_by(&:recorded_on)
    extra_off = DailyRoutineOffDay.for_owner(@owner_key).covering(padded).pluck(:off_on).to_set
    classifier = DailyRoutineDayClassifier.new(owner_key: @owner_key, extra_off_dates: extra_off)

    entry_dates = Entry.unsettled
      .where(created_at: padded.begin.beginning_of_day..padded.end.end_of_day)
      .pluck(:created_at)
      .map { |t| t.in_time_zone.to_date }
      .to_set

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
            entry_in_period =
              if period
                period.any? { |d| entry_dates.include?(d) }
              else
                false
              end

            DailyRoutineStatus.new(
              owner_key: @owner_key,
              date: cell_date,
              note: notes[cell_date],
              classifier: classifier,
              entry_plan_in_period: entry_in_period
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
end
