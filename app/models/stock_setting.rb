# frozen_string_literal: true

class StockSetting < ApplicationRecord
  DEFAULT_CHART_ID = "8WvKf6oB"

  validates :tradingview_chart_id, presence: true, length: { maximum: 40 }
  validates :tradingview_chart_id, format: { with: /\A[A-Za-z0-9]+\z/, message: "は英数字のみです" }

  before_validation :normalize_chart_id

  def self.instance
    order(:id).first_or_create!(tradingview_chart_id: DEFAULT_CHART_ID)
  end

  def self.tradingview_chart_id
    instance.tradingview_chart_id.presence || DEFAULT_CHART_ID
  end

  private

  def normalize_chart_id
    self.tradingview_chart_id = tradingview_chart_id.to_s.strip
  end
end
