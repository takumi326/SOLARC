# frozen_string_literal: true

class DailyRoutineStatus
  SlotStatus = Data.define(:slot, :label, :completed, :items, :emphasized, :completion_hint)

  def initialize(owner_key:, date: Date.current, note: nil, has_entry_plan: nil, classifier: nil, entry_plan_in_period: nil)
    @owner_key = owner_key
    @date = date
    @note = note
    @has_entry_plan = has_entry_plan
    @classifier = classifier || DailyRoutineDayClassifier.new(owner_key: owner_key)
    @entry_plan_in_period = entry_plan_in_period
  end

  def call
    DailyRoutineItem.ensure_defaults_for!(@owner_key)
    items_by_slot = DailyRoutineItem.for_owner(@owner_key).ordered.group_by(&:slot)
    off = off_day?

    DailyRoutineItem::SLOTS.map do |slot|
      SlotStatus.new(
        slot: slot,
        label: DailyRoutineItem::SLOT_LABELS.fetch(slot),
        completed: completed?(slot),
        items: items_by_slot[slot] || [],
        emphasized: off ? slot == "holiday" : slot != "holiday",
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

  def off_day?
    @classifier.off_day?(@date)
  end

  def off_period
    @off_period ||= @classifier.off_period(@date)
  end

  private

  def emphasized_slots
    off_day? ? %w[holiday] : %w[weekday_morning weekday_evening]
  end

  def completed?(slot)
    case slot
    when "weekday_morning"
      note_field_present?(:hypothesis)
    when "weekday_evening"
      note_field_present?(:result)
    when "holiday"
      holiday_entry_plan?
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

  def holiday_entry_plan?
    return @entry_plan_in_period unless @entry_plan_in_period.nil?
    return @has_entry_plan unless @has_entry_plan.nil?

    period = off_period
    return false unless period

    Entry.unsettled.where(created_at: period.begin.beginning_of_day..period.end.end_of_day).exists?
  end

  def completion_hint_for(slot)
    case slot
    when "weekday_morning"
      "#{date_label}の毎日の記録に仮説がある"
    when "weekday_evening"
      "#{date_label}の毎日の記録に結果がある"
    when "holiday"
      "この休み期間（#{period_label}）に未約定エントリーがある"
    else
      ""
    end
  end

  def date_label
    @date == Date.current ? "今日" : @date.strftime("%-m/%-d")
  end

  def period_label
    period = off_period
    return date_label unless period

    if period.begin == period.end
      period.begin.strftime("%-m/%-d")
    else
      "#{period.begin.strftime("%-m/%-d")}〜#{period.end.strftime("%-m/%-d")}"
    end
  end
end
