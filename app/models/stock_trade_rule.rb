# frozen_string_literal: true

class StockTradeRule < ApplicationRecord
  DEFAULT_TITLE = "取引ルール"

  validates :title, presence: true, length: { maximum: 100 }
  validates :body, length: { maximum: 500_000 }, allow_blank: true

  def self.instance
    order(:id).first_or_create!(title: DEFAULT_TITLE, body: "")
  end

  def updated_on_label
    updated_at.in_time_zone.strftime("%Y/%m/%d")
  end
end
