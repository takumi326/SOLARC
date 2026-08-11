# frozen_string_literal: true

class CreateDailyRoutineItems < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_routine_items do |t|
      t.string :owner_key, null: false, limit: 255
      t.string :slot, null: false, limit: 32
      t.string :label, null: false, limit: 255
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :daily_routine_items, [ :owner_key, :slot, :position ],
              name: "index_daily_routine_items_on_owner_slot_position"
  end
end
