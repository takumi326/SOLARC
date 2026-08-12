# frozen_string_literal: true

class StockWatchItem < ApplicationRecord
  belongs_to :stock_watch_batch
  belongs_to :stock

  validates :source_label, presence: true, length: { maximum: 100 }
  validates :stock_id, uniqueness: { scope: :stock_watch_batch_id }
end
