# frozen_string_literal: true

# 既存オーナーには月末枠の既定項目が無いため、ここで一度だけ追加する。
class BackfillMonthEndRoutineItems < ActiveRecord::Migration[8.1]
  SLOT = "month_end"

  def up
    labels = DailyRoutineItem::DEFAULT_LABELS[SLOT]
    return if labels.blank?

    owner_keys = DailyRoutineItem.distinct.pluck(:owner_key) -
                 DailyRoutineItem.where(slot: SLOT).distinct.pluck(:owner_key)

    owner_keys.each do |owner_key|
      labels.each_with_index do |label, index|
        DailyRoutineItem.create!(owner_key: owner_key, slot: SLOT, label: label, position: index)
      end
    end
  end

  def down
    DailyRoutineItem.where(slot: SLOT).delete_all
  end
end
