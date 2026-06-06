class UserPreference < ApplicationRecord
  validates :owner_key, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :import_claude_prompt_template, length: { maximum: 50_000 }, allow_nil: true

  # ridgepole 未適用の DB では列が無く、未定義属性のバリデーションで落ちるのを防ぐ
  validates :stock_daily_hypothesis_template, length: { maximum: 500_000 }, allow_nil: true,
            if: -> { self.class.column_names.include?("stock_daily_hypothesis_template") }
  validates :stock_daily_hypothesis_prompt, length: { maximum: 500_000 }, allow_nil: true,
            if: -> { self.class.column_names.include?("stock_daily_hypothesis_prompt") }
  validates :stock_daily_result_prompt, length: { maximum: 500_000 }, allow_nil: true,
            if: -> { self.class.column_names.include?("stock_daily_result_prompt") }
  validates :stock_daily_sector_prompt, length: { maximum: 500_000 }, allow_nil: true,
            if: -> { self.class.column_names.include?("stock_daily_sector_prompt") }
end
