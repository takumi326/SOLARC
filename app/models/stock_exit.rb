# frozen_string_literal: true

# DB テーブル名は設計書どおり `exits`（Exit は Kernel#exit と紛らわしいため StockExit）
class StockExit < ApplicationRecord
  self.table_name = "exits"

  include StockTradeAxes

  validates :exit_reason, presence: true
  validates :shares, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :review_result, inclusion: { in: %w[as_planned missed partial] }, allow_nil: true

  scope :settled, -> { where.not(traded_at: nil) }
  scope :unsettled, -> { where(traded_at: nil) }
end
