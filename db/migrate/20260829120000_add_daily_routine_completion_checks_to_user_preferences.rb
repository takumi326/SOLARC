# frozen_string_literal: true

class AddDailyRoutineCompletionChecksToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :user_preferences, :daily_routine_completion_checks, :jsonb, default: {}, null: false
  end
end
