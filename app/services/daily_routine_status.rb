# frozen_string_literal: true

class DailyRoutineStatus
  SlotStatus = Data.define(:slot, :label, :completed, :items, :emphasized, :completion_hint,
                           :month, :date) do
    def initialize(month: nil, date: nil, **) = super
  end

  # これより前の月は取り込み記録が無いため対象外にする
  TRACKING_START_MONTH = Date.new(2026, 7, 1)

  def initialize(owner_key:, date: Date.current, note: nil, has_watchlist_import: nil, classifier: nil,
                 watchlist_imported_in_period: nil, imported_months: nil)
    @owner_key = owner_key
    @date = date
    @note = note
    @has_watchlist_import = has_watchlist_import
    @classifier = classifier || DailyRoutineDayClassifier.new(owner_key: owner_key)
    @watchlist_imported_in_period = watchlist_imported_in_period
    @given_imported_months = imported_months
  end

  def call
    DailyRoutineItem.ensure_defaults_for!(@owner_key)
    items_by_slot = DailyRoutineItem.for_owner(@owner_key).ordered.group_by(&:slot)
    emphasized = day_slots

    statuses = DailyRoutineItem::SLOTS.filter_map do |slot|
      next if slot == "month_end"

      SlotStatus.new(
        slot: slot,
        label: DailyRoutineItem::SLOT_LABELS.fetch(slot),
        completed: completed?(slot),
        items: items_by_slot[slot] || [],
        # 休日は未完了なら休み期間中ずっと、完了後は完了日だけ出す（履歴）
        emphasized: slot == "holiday" ? holiday_card_visible? : emphasized.include?(slot),
        completion_hint: completion_hint_for(slot),
        date: @date
      )
    end

    statuses + month_end_statuses(items_by_slot["month_end"] || [])
  end

  def day_status
    # カレンダーの色は日次ルーチンだけ。月末取込は含めない。
    results = day_slots.map { |slot| completed?(slot) }
    return :none if results.empty?

    done = results.count(true)
    return :complete if done == results.size
    return :partial if done.positive?

    :incomplete
  end

  def off_day?
    @classifier.off_day?(@date)
  end

  def off_period
    @off_period ||= @classifier.off_period(@date)
  end

  # やること: 休み期間中は出す。完了後の履歴: 完了日だけ出す。
  def holiday_card_visible?
    return false unless off_day?
    return true unless holiday_watchlist_imported?

    completed_on = holiday_completed_on
    return true if completed_on.nil?

    completed_on == @date
  end

  # やることカード: 未取込は翌月1日から、取込済みは取込日だけ。
  def due_months
    @due_months ||= tracked_months.select { |month| month_end_todo?(month) }
  end

  def month_end_todo?(month)
    return false if @date < self.class.month_end_available_from(month)

    imported = imported_on(month)
    return true if imported.nil?

    imported == @date
  end

  def imported_on(month)
    imported_months[month]
  end

  def self.month_end_available_from(month)
    month.next_month.beginning_of_month
  end

  def self.imported_months_for(months)
    return {} if months.empty?

    Expense.expense_type_one_time.imported
           .where(start_month: months)
           .pluck(:start_month, :imported_at)
           .each_with_object({}) do |(month, imported_at), result|
      date = imported_at.in_time_zone.to_date
      # 当月中の取込は月末ルーチン完了に使わない（翌月1日以降のみ）
      next if date < month_end_available_from(month)

      result[month] = [ result[month], date ].compact.max
    end
  end

  private

  def month_end_statuses(items)
    due_months.map do |month|
      SlotStatus.new(
        slot: "month_end",
        label: "#{month.strftime("%-m月")}末",
        completed: imported_on(month).present?,
        items: items,
        emphasized: true,
        completion_hint: "翌月以降に#{month.strftime("%-m月")}分の支払いを取り込んでいる",
        month: month
      )
    end
  end

  def day_slots
    off_day? ? %w[holiday] : %w[weekday_morning weekday_evening]
  end

  def completed?(slot)
    case slot
    when "weekday_morning"
      note_field_present?(:hypothesis)
    when "weekday_evening"
      note_field_present?(:result)
    when "holiday"
      holiday_watchlist_imported?
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

  def holiday_watchlist_imported?
    return @watchlist_imported_in_period unless @watchlist_imported_in_period.nil?
    return @has_watchlist_import unless @has_watchlist_import.nil?

    holiday_completed_on.present?
  end

  def holiday_completed_on
    return @holiday_completed_on if defined?(@holiday_completed_on)

    period = off_period
    @holiday_completed_on =
      if period
        StockWatchBatch.imported_between(period.begin..period.end).minimum(:imported_on)
      end
  end

  # 対象日までに出番が来ている可能性のある月（古い順）
  def tracked_months
    @tracked_months ||= begin
      months = []
      month = TRACKING_START_MONTH
      while month <= @date.beginning_of_month
        months << month
        month = month.next_month
      end
      months
    end
  end

  def imported_months
    @imported_months ||= @given_imported_months || self.class.imported_months_for(tracked_months)
  end

  def completion_hint_for(slot)
    case slot
    when "weekday_morning"
      "#{date_label}の毎日の記録に仮説がある"
    when "weekday_evening"
      "#{date_label}の毎日の記録に結果がある"
    when "holiday"
      "この休み期間（#{period_label}）に監視銘柄リストを取り込んでいる"
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
