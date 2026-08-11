# frozen_string_literal: true

class DailyRoutinesController < ApplicationController
  def show
    @date = parse_date(params[:date]) || Date.current
    @month = parse_month(params[:month]) || @date.beginning_of_month
    @slots = DailyRoutineStatus.new(owner_key: preference_owner_key, date: @date).call
    @calendar = DailyRoutineCalendar.new(
      owner_key: preference_owner_key,
      month: @month,
      selected_date: @date
    ).call
  end

  private

  def parse_date(value)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def parse_month(value)
    return if value.blank?

    Date.strptime(value.to_s, "%Y-%m")
  rescue ArgumentError, TypeError
    nil
  end
end
