# frozen_string_literal: true

class CreateDailyRoutineOffDays < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_routine_off_days do |t|
      t.string :owner_key, null: false, limit: 255
      t.date :off_on, null: false
      t.timestamps
    end

    add_index :daily_routine_off_days, [ :owner_key, :off_on ], unique: true,
              name: "index_daily_routine_off_days_on_owner_key_and_off_on"
  end
end
