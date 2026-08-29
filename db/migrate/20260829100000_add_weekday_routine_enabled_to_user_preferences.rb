# frozen_string_literal: true

class AddWeekdayRoutineEnabledToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :user_preferences, :weekday_morning_routine_enabled, :boolean, default: true, null: false
    add_column :user_preferences, :weekday_evening_routine_enabled, :boolean, default: true, null: false
  end
end
