# frozen_string_literal: true

class DailyRoutineCalendar
  DayCell = Data.define(:date, :in_month, :selected, :today, :status)
  MonthView = Data.define(:month, :weeks, :prev_month, :next_month)

  def initialize(owner_key:, month:, selected_date:)
    @owner_key = owner_key
    @month = month.to_date.beginning_of_month
    @selected_date = selected_date.to_date
  end

  def call
    range = @month..@month.end_of_month
    notes = StockDailyNote.where(owner_key: @owner_key, recorded_on: range).index_by(&:recorded_on)
    entry_dates = Entry.unsettled
      .where(created_at: range.begin.beginning_of_day..range.end.end_of_day)
      .pluck(:created_at)
      .map { |t| t.in_time_zone.to_date }
      .to_set

    grid_start = @month.beginning_of_week(:sunday)
    grid_end = @month.end_of_month.end_of_week(:sunday)

    weeks = []
    day = grid_start
    while day <= grid_end
      week = (0..6).map do
        cell_date = day
        in_month = cell_date.month == @month.month
        status =
          if in_month
            DailyRoutineStatus.new(
              owner_key: @owner_key,
              date: cell_date,
              note: notes[cell_date],
              has_entry_plan: entry_dates.include?(cell_date)
            ).day_status
          else
            :outside
          end

        cell = DayCell.new(
          date: cell_date,
          in_month: in_month,
          selected: cell_date == @selected_date,
          today: cell_date == Date.current,
          status: status
        )
        day += 1
        cell
      end
      weeks << week
    end

    MonthView.new(
      month: @month,
      weeks: weeks,
      prev_month: @month.prev_month,
      next_month: @month.next_month
    )
  end
end
