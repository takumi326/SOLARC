class UserPreference < ApplicationRecord
  validates :owner_key, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :import_claude_prompt_template, length: { maximum: 50_000 }, allow_nil: true,
            if: -> { self.class.column_names.include?("import_claude_prompt_template") }
  validates :import_merchant_rules, length: { maximum: 20_000 }, allow_nil: true,
            if: -> { self.class.column_names.include?("import_merchant_rules") }

  def import_claude_prompt_template
    return nil unless self.class.column_names.include?("import_claude_prompt_template")

    self[:import_claude_prompt_template]
  end

  def import_claude_prompt_template=(value)
    return unless self.class.column_names.include?("import_claude_prompt_template")

    self[:import_claude_prompt_template] = value
  end

  def import_merchant_rules
    return nil unless self.class.column_names.include?("import_merchant_rules")

    self[:import_merchant_rules]
  end

  def import_merchant_rules=(value)
    return unless self.class.column_names.include?("import_merchant_rules")

    self[:import_merchant_rules] = value
  end

  # migration 未適用の DB では列が無く、未定義属性のバリデーションで落ちるのを防ぐ
  validates :stock_daily_hypothesis_template, length: { maximum: 500_000 }, allow_nil: true,
            if: -> { self.class.column_names.include?("stock_daily_hypothesis_template") }
  validates :stock_daily_hypothesis_prompt, length: { maximum: 500_000 }, allow_nil: true,
            if: -> { self.class.column_names.include?("stock_daily_hypothesis_prompt") }
  validates :stock_daily_result_prompt, length: { maximum: 500_000 }, allow_nil: true,
            if: -> { self.class.column_names.include?("stock_daily_result_prompt") }
  validates :stock_daily_sector_prompt, length: { maximum: 500_000 }, allow_nil: true,
            if: -> { self.class.column_names.include?("stock_daily_sector_prompt") }
  validates :stock_fundamentals_prompt, length: { maximum: 500_000 }, allow_nil: true,
            if: -> { self.class.column_names.include?("stock_fundamentals_prompt") }

  def daily_routine_slot_enabled?(slot)
    column = self.class.daily_routine_slot_enabled_column(slot)
    return true unless column
    return true unless self.class.column_names.include?(column)

    value = self[column]
    value.nil? ? true : value
  end

  def set_daily_routine_slot_enabled!(slot, enabled)
    column = self.class.daily_routine_slot_enabled_column(slot)
    raise ArgumentError, "unknown slot: #{slot}" unless column
    return unless self.class.column_names.include?(column)

    self[column] = enabled
    save!
  end

  def self.daily_routine_slot_enabled_column(slot)
    case slot.to_s
    when "weekday_morning" then "weekday_morning_routine_enabled"
    when "weekday_evening" then "weekday_evening_routine_enabled"
    end
  end

  def daily_routine_completion_check_keys(slot)
    return DailyRoutineItem::DEFAULT_COMPLETION_CHECKS unless DailyRoutineItem::TOGGLEABLE_SLOTS.include?(slot.to_s)
    return DailyRoutineItem::DEFAULT_COMPLETION_CHECKS unless completion_checks_column?

    stored = daily_routine_completion_checks_hash[slot.to_s]
    return DailyRoutineItem::DEFAULT_COMPLETION_CHECKS if stored.nil?

    DailyRoutineItem::SELECTABLE_COMPLETION_CHECKS.select { |key| Array(stored).map(&:to_s).include?(key) }
  end

  def daily_routine_completion_check_enabled?(slot, key)
    daily_routine_completion_check_keys(slot).include?(key.to_s)
  end

  def set_daily_routine_completion_checks!(slot, keys)
    raise ArgumentError, "unknown slot: #{slot}" unless DailyRoutineItem::TOGGLEABLE_SLOTS.include?(slot.to_s)
    return unless completion_checks_column?

    selected = DailyRoutineItem::SELECTABLE_COMPLETION_CHECKS.select { |key| Array(keys).map(&:to_s).include?(key) }
    data = daily_routine_completion_checks_hash.merge(slot.to_s => selected)
    self[:daily_routine_completion_checks] = data
    save!
  end

  private

  def completion_checks_column?
    self.class.column_names.include?("daily_routine_completion_checks")
  end

  def daily_routine_completion_checks_hash
    return {} unless completion_checks_column?

    raw = self[:daily_routine_completion_checks]
    return {} if raw.blank?

    raw = JSON.parse(raw) if raw.is_a?(String)
    raw.is_a?(Hash) ? raw.stringify_keys : {}
  rescue JSON::ParserError
    {}
  end
end
