# frozen_string_literal: true

class DailyRoutinesController < ApplicationController
  def show
    @date = parse_date(params[:date]) || Date.current
    @month = parse_month(params[:month]) || @date.beginning_of_month
    @preference = UserPreference.find_or_initialize_by(owner_key: preference_owner_key)
    @classifier = DailyRoutineDayClassifier.new(owner_key: preference_owner_key)
    @status = DailyRoutineStatus.new(
      owner_key: preference_owner_key,
      date: @date,
      classifier: @classifier,
      preference: @preference
    )
    @slots = @status.call
    @off_day = @status.off_day?
    @weekend = @classifier.weekend?(@date)
    @marked_off = @classifier.marked_off?(@date)
    @calendar = DailyRoutineCalendar.new(
      owner_key: preference_owner_key,
      month: @month,
      selected_date: @date,
      preference: @preference
    ).call
    @routine_history = DailyRoutineHistory.new(
      owner_key: preference_owner_key,
      date: @date,
      classifier: @classifier,
      status: @status
    )
  end

  def create_off_day
    date = parse_date(params[:date]) || Date.current
    if date.saturday? || date.sunday?
      redirect_to daily_routine_path(date: date.iso8601), alert: "土日はもともと休み扱いです。"
      return
    end

    DailyRoutineOffDay.find_or_create_by!(owner_key: preference_owner_key, off_on: date)
    redirect_to daily_routine_path(date: date.iso8601), notice: "#{date.strftime("%-m/%-d")} を休みにしました。"
  end

  def destroy_off_day
    date = parse_date(params[:date]) || Date.current
    DailyRoutineOffDay.for_owner(preference_owner_key).where(off_on: date).destroy_all
    redirect_to daily_routine_path(date: date.iso8601), notice: "#{date.strftime("%-m/%-d")} の休み指定を解除しました。"
  end

  def update_slot_setting
    slot = params[:slot].to_s
    unless DailyRoutineItem::TOGGLEABLE_SLOTS.include?(slot)
      redirect_to slot_setting_redirect_path, alert: "不正な枠です。"
      return
    end

    enabled = ActiveModel::Type::Boolean.new.cast(params[:enabled])
    preference = UserPreference.find_or_initialize_by(owner_key: preference_owner_key)
    preference.set_daily_routine_slot_enabled!(slot, enabled)

    label = DailyRoutineItem::SLOT_LABELS.fetch(slot)
    notice = enabled ? "#{label}のルーチンをオンにしました。" : "#{label}のルーチンをオフにしました。"
    redirect_to slot_setting_redirect_path, notice: notice
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

  def slot_setting_redirect_path
    if params[:from] == "settings"
      daily_routine_settings_path
    else
      date = parse_date(params[:date]) || Date.current
      daily_routine_path(date: date.iso8601)
    end
  end
end
