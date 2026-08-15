# frozen_string_literal: true

class StockIndexQuery
  Result = Data.define(:stocks, :stock_flags)

  class << self
    def call
      new.call
    end
  end

  def call
    sets = [ Stock.watched, Stock.with_real_holdings, Stock.with_virtual_holdings ]
    scope = Stock.includes(:industry).where(id: sets.reduce { |combined, set| combined.or(set) }.select(:id))
    scope = scope.with_current_flags.order(Arel.sql("current_entered DESC, stocks.watched DESC, stocks.code ASC"))
    stocks = scope.to_a

    Result.new(stocks: stocks, stock_flags: current_status_flags(stocks))
  end

  private

  def current_status_flags(stocks)
    return {} if stocks.empty?

    ids = stocks.map(&:id)
    watching_ids = StockWatchItem.joins(:stock_watch_batch)
      .merge(StockWatchBatch.covering(Time.zone.today))
      .where(stock_id: ids)
      .distinct
      .pluck(:stock_id)
      .to_set

    holding_by_stock = Position.open.real.human.where(stock_id: ids).where("quantity > 0").group(:stock_id).sum(:quantity)
    virtual_rel = Position.open.virtual.where(stock_id: ids).where("quantity > 0")
    virtual_rel = virtual_rel.human unless AiTradeFeatures.enabled?
    virtual_holding_by_stock = virtual_rel.group(:stock_id).sum(:quantity)

    stocks.each_with_object({}) do |stock, hash|
      hash[stock.id] = {
        watching: watching_ids.include?(stock.id),
        holding: holding_by_stock.fetch(stock.id, 0).positive?,
        virtual_holding: virtual_holding_by_stock.fetch(stock.id, 0).positive?
      }
    end
  end
end
