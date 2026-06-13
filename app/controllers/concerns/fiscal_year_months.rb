# 今年度を「4月始まり・翌年3月まで」（アンカー月を含む年度の12ヶ月）
module FiscalYearMonths
  extend ActiveSupport::Concern

  private

  def fiscal_month_starts(anchor)
    y = anchor.year
    m = anchor.month
    fiscal_year = m >= 4 ? y : y - 1
    start = Date.new(fiscal_year, 4, 1)
    (0..11).map { |i| start.advance(months: i) }
  end
end
