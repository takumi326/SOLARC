# frozen_string_literal: true

class Entry < ApplicationRecord
  include StockTradeAxes

  validates :entry_reason, presence: true
  validates :shares, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  scope :settled, -> { where.not(traded_at: nil) }
  scope :unsettled, -> { where(traded_at: nil) }
end
