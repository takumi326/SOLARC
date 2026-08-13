class StockDailyNote < ApplicationRecord
  DEFAULT_HYPOTHESIS = [
    "## 米国市場",
    "",
    "",
    "## 国内市況",
    "",
    "## ニュース",
    "- ",
    "",
    "## 個別材料",
    "- ",
    ""
  ].join("\n").freeze

  DEFAULT_RESULT = [
    "## 所有株",
    "- ",
    "",
    "## 日経平均、TOPIX",
    "- 日経平均：",
    "- TOPIX　：",
    "",
    "## セクター",
    "- ",
    ""
  ].join("\n").freeze

  validates :owner_key, presence: true, length: { maximum: 255 }
  validates :recorded_on, presence: true
  validates :recorded_on, uniqueness: { scope: :owner_key }
  validates :hypothesis, length: { maximum: 500_000 }, allow_blank: true
  validates :result, length: { maximum: 500_000 }, allow_blank: true
  validates :sector_research, length: { maximum: 500_000 }, allow_blank: true
end
