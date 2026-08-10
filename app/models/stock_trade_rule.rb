# frozen_string_literal: true

class StockTradeRule < ApplicationRecord
  validates :title, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :body, presence: true, length: { maximum: 500_000 }
end
