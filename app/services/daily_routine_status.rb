# frozen_string_literal: true

class DailyRoutineStatus
  SlotStatus = Data.define(:slot, :label, :completed, :items, :emphasized, :completion_hint)

  def initialize(owner_key:, date: Date.current, note: nil, has_entry_plan: nil)
    @owner_key = owner_key
    @date = date
    @note = note
    @has_entry_plan = has_entry_plan
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
        completion_hint: completion_hint_for(slot)
      )
    end
  end

  def day_status
    slots = emphasized_slots
    return :none if slots.empty?

    done = slots.count { |slot| completed?(slot) }
    return :complete if done == slots.size
    return :partial if done.positive?

    :incomplete
  end

  private

  def weekend?
    @date.saturday? || @date.sunday?
  end

  def emphasized_slots
    weekend? ? %w[holiday] : %w[weekday_morning weekday_evening]
  end

  def completed?(slot)
    case slot
    when "weekday_morning"
      note_field_present?(:hypothesis)
    when "weekday_evening"
      note_field_present?(:result)
    when "holiday"
      entry_plan?
    else
      false
    end
  end

  def note
    @note ||= StockDailyNote.find_by(owner_key: @owner_key, recorded_on: @date)
  end

  def note_field_present?(field)
    return false unless note

    note.public_send(field).to_s.strip.present?
  end

  def entry_plan?
    return @has_entry_plan unless @has_entry_plan.nil?

    Entry.unsettled.where(created_at: @date.all_day).exists?
  end

  def completion_hint_for(slot)
    label = date_label
    case slot
    when "weekday_morning"
      "#{label}の毎日の記録に仮説があると完了"
    when "weekday_evening"
      "#{label}の毎日の記録に結果があると完了"
    when "holiday"
      "#{label}につくった未約定エントリーがあると完了"
    else
      ""
    end
  end

  def date_label
    @date == Date.current ? "今日" : @date.strftime("%-m/%-d")
  end
end
