# frozen_string_literal: true

class LineChange < ApplicationRecord
  include StockTradeAxes
  include OptionalDecimalFields

  validates :changed_on, presence: true
  validates_optional_decimal :stop_loss, :target_price
end
