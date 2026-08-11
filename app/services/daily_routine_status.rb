# frozen_string_literal: true

class DailyRoutineStatus
  COMPLETION_HINTS = {
    "weekday_morning" => "今日の毎日の記録に仮説があると完了",
    "weekday_evening" => "今日の毎日の記録に結果があると完了",
    "holiday" => "今日つくった未約定エントリーがあると完了"
  }.freeze

  SlotStatus = Data.define(:slot, :label, :completed, :items, :emphasized, :completion_hint)

  def initialize(owner_key:, date: Date.current)
    @owner_key = owner_key
    @date = date
  end

  def call
    DailyRoutineItem.ensure_defaults_for!(@owner_key)
    items_by_slot = DailyRoutineItem.for_owner(@owner_key).ordered.group_by(&:slot)
    holiday = weekend?

    DailyRoutineItem::SLOTS.map do |slot|
      SlotStatus.new(
        slot: slot,
        label: DailyRoutineItem::SLOT_LABELS.fetch(slot),
        completed: completed?(slot),
        items: items_by_slot[slot] || [],
        emphasized: holiday ? slot == "holiday" : slot != "holiday",
        completion_hint: COMPLETION_HINTS.fetch(slot)
      )
    end
  end

  private

  def weekend?
    @date.saturday? || @date.sunday?
  end

  def completed?(slot)
    case slot
    when "weekday_morning"
      note_field_present?(:hypothesis)
    when "weekday_evening"
      note_field_present?(:result)
    when "holiday"
      entry_plan_today?
    else
      false
    end
  end

  def note_field_present?(field)
    note = StockDailyNote.find_by(owner_key: @owner_key, recorded_on: @date)
    return false unless note

    note.public_send(field).to_s.strip.present?
  end

  def entry_plan_today?
    Entry.unsettled.where(created_at: @date.all_day).exists?
  end
end
