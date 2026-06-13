class StockDailyNote < ApplicationRecord
  validates :owner_key, presence: true, length: { maximum: 255 }
  validates :recorded_on, presence: true
  validates :recorded_on, uniqueness: { scope: :owner_key }
  validates :hypothesis, length: { maximum: 500_000 }, allow_blank: true
  validates :result, length: { maximum: 500_000 }, allow_blank: true
  validates :sector_research, length: { maximum: 500_000 }, allow_blank: true
end
