# frozen_string_literal: true

# 設計書 5.4: 約定済みイグジットについて、同一銘柄・軸のエントリー平均単価（約定日以前）×株数を控除
class StockRealizedPl
  class << self
    def total_for_exits(scope)
      scope = scope.where.not(traded_at: nil).where.not(actual_price: nil).where.not(shares: nil)
      scope.reduce(BigDecimal("0")) do |acc, x|
        avg = avg_entry_actual_price(
          stock_id: x.stock_id,
          trade_type: x.trade_type,
          judgment_type: x.judgment_type,
          on_or_before: x.traded_at
        )
        next acc if avg.nil?

        acc + ((x.actual_price.to_d * x.shares) - (avg * x.shares))
      end
    end

    def avg_entry_actual_price(stock_id:, trade_type:, judgment_type:, on_or_before:)
      q = Entry.where(stock_id: stock_id, trade_type: trade_type, judgment_type: judgment_type)
      q = q.where.not(traded_at: nil).where.not(actual_price: nil).where("traded_at <= ?", on_or_before)
      q.average(:actual_price)&.to_d
    end
  end
end
