# frozen_string_literal: true

class Entry < ApplicationRecord
  include StockTradeAxes

  DATE_SQL = "COALESCE(entries.traded_at, DATE(entries.created_at))"

  validates :entry_reason, presence: true
  validates :shares, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  scope :settled, -> { where.not(traded_at: nil) }
  scope :unsettled, -> { where(traded_at: nil) }

  # 約定日（未約定は登録日）で絞り込む。片側だけの指定も許す。
  scope :dated_between, lambda { |starts_on, ends_on|
    scope = all
    scope = scope.where("#{DATE_SQL} >= ?", starts_on) if starts_on.present?
    scope = scope.where("#{DATE_SQL} <= ?", ends_on) if ends_on.present?
    scope
  }
end
