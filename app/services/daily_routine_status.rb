# frozen_string_literal: true

class DailyRoutineStatus
  CompletionCheck = Data.define(:key, :label, :completed)

  SlotStatus = Data.define(:slot, :label, :completed, :items, :emphasized, :completion_checks,
                           :month, :date) do
    def initialize(month: nil, date: nil, completion_checks: [], **) = super
  end

  # これより前の月は取り込み記録が無いため対象外にする
  TRACKING_START_MONTH = Date.new(2026, 7, 1)

  def initialize(owner_key:, date: Date.current, note: nil, has_watchlist_import: nil, classifier: nil,
                 watchlist_imported_in_period: nil, imported_months: nil, preference: nil,
                 has_watched_stocks: nil)
    @owner_key = owner_key
    @date = date
    @note = note
    @has_watchlist_import = has_watchlist_import
    @classifier = classifier || DailyRoutineDayClassifier.new(owner_key: owner_key)
    @watchlist_imported_in_period = watchlist_imported_in_period
    @given_imported_months = imported_months
    @preference = preference
    @has_watched_stocks = has_watched_stocks
  end

  def call
    DailyRoutineItem.ensure_defaults_for!(@owner_key)
    items_by_slot = DailyRoutineItem.for_owner(@owner_key).ordered.group_by(&:slot)
    emphasized = day_slots

    statuses = DailyRoutineItem::SLOTS.filter_map do |slot|
      next if slot == "month_end"
      next unless slot_enabled?(slot)

      checks = completion_checks_for(slot)
      SlotStatus.new(
        slot: slot,
        label: DailyRoutineItem::SLOT_LABELS.fetch(slot),
        completed: checks.all?(&:completed),
        items: items_by_slot[slot] || [],
        # 休日は未完了なら休み期間中ずっと、完了後は完了日だけ出す（履歴）
        emphasized: slot == "holiday" ? holiday_card_visible? : emphasized.include?(slot),
        completion_checks: checks,
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
      imported = imported_on(month).present?
      checks = [
        CompletionCheck.new(
          key: :month_end_import,
          label: "翌月以降に#{month.strftime("%-m月")}分の支払いを取り込んでいる",
          completed: imported
        )
      ]
      SlotStatus.new(
        slot: "month_end",
        label: "#{month.strftime("%-m月")}末",
        completed: imported,
        items: items,
        emphasized: true,
        completion_checks: checks,
        month: month
      )
    end
  end

  def day_slots
    return %w[holiday] if off_day?

    DailyRoutineItem::TOGGLEABLE_SLOTS.select { |slot| slot_enabled?(slot) }
  end

  def slot_enabled?(slot)
    return true unless DailyRoutineItem::TOGGLEABLE_SLOTS.include?(slot)
    return true unless current_or_future?

    preference.daily_routine_slot_enabled?(slot)
  end

  def current_or_future?
    @date >= Date.current
  end

  def preference
    @preference ||= UserPreference.find_or_initialize_by(owner_key: @owner_key)
  end

  def completed?(slot)
    completion_checks_for(slot).all?(&:completed)
  end

  def completion_checks_for(slot)
    case slot
    when "weekday_morning", "weekday_evening"
      weekday_completion_check_keys(slot).filter_map { |key| weekday_completion_check(slot, key) }
    when "holiday"
      [
        CompletionCheck.new(
          key: :holiday_watchlist,
          label: "この休み期間（#{period_label}）に監視銘柄リストを取り込んでいる",
          completed: holiday_watchlist_imported?
        )
      ]
    else
      []
    end
  end

  def weekday_completion_check_keys(slot)
    return DailyRoutineItem::DEFAULT_COMPLETION_CHECKS unless current_or_future?

    preference.daily_routine_completion_check_keys(slot)
  end

  def weekday_completion_check(slot, key)
    case key.to_s
    when "daily_note"
      CompletionCheck.new(key: :daily_note, label: DailyRoutineItem::COMPLETION_CHECK_LABELS.fetch("daily_note"),
                          completed: daily_note_completed?(slot))
    when "watched_stocks"
      CompletionCheck.new(key: :watched_stocks, label: watched_stocks_label, completed: has_watched_stocks?)
    end
  end

  def daily_note_completed?(slot)
    note_field_present?(slot == "weekday_morning" ? :hypothesis : :result)
  end

  def has_watched_stocks?
    return @has_watched_stocks unless @has_watched_stocks.nil?

    StockWatchItem.joins(:stock_watch_batch).merge(StockWatchBatch.covering(@date)).exists?
  end

  def watched_stocks_label
    @date == Date.current ? "今日監視銘柄がある" : "この日に監視銘柄がある"
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
