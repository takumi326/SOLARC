# frozen_string_literal: true

class LineChange < ApplicationRecord
  include StockTradeAxes

  validates :changed_on, presence: true
end
