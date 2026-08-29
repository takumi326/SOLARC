# frozen_string_literal: true

class StockIndexQuery
  Result = Data.define(:stocks, :stock_flags)

  class << self
    def call(...)
      new.call(...)
    end
  end

  def call(starts_on: nil, ends_on: nil)
    if starts_on.present? && ends_on.present?
      watch_period_stocks(starts_on, ends_on)
    else
      stocks = holding_stocks
      Result.new(stocks: stocks, stock_flags: flags_for(stocks))
    end
  end

  def holding_stocks
    Stock.includes(:industry).with_real_holdings.with_current_flags.order(Arel.sql("current_entered DESC, stocks.code ASC")).to_a
  end

  def watch_period_stocks(starts_on, ends_on)
    ids = StockWatchItem.joins(:stock_watch_batch)
      .where(stock_watch_batches: { starts_on: starts_on, ends_on: ends_on })
      .select(:stock_id)
    stocks_for_ids(ids, watch_starts_on: starts_on, watch_ends_on: ends_on)
  end

  def current_watch_stocks
    ids = StockWatchItem.joins(:stock_watch_batch)
      .merge(StockWatchBatch.covering(StockWatchBatch.effective_watch_date))
      .select(:stock_id)
    stocks_for_ids(ids)
  end

  def stocks_for_ids(ids, watch_starts_on: nil, watch_ends_on: nil)
    stocks = Stock.includes(:industry).where(id: ids).with_current_flags.order(Arel.sql("current_entered DESC, stocks.code ASC")).to_a
    Result.new(stocks: stocks, stock_flags: flags_for(stocks, watch_starts_on: watch_starts_on, watch_ends_on: watch_ends_on))
  end

  def lookup(q, limit: 20)
    stocks = Stock.search_by_term(q).includes(:industry).to_a
    flags = flags_for(stocks)
    stocks.sort_by! { |stock| [ lookup_rank(flags[stock.id]), stock.code.to_s ] }
    stocks.first(limit)
  end

  def lookup_rank(status)
    status ||= {}
    return 0 if status[:holding]
    return 1 if status[:watching]
    return 2 if status[:virtual_holding]

    3
  end

  def flags_for(stocks, watch_starts_on: nil, watch_ends_on: nil)
    return {} if stocks.empty?

    ids = stocks.map(&:id)
    watching_rel = StockWatchItem.joins(:stock_watch_batch).where(stock_id: ids)
    watching_rel = if watch_starts_on.present? && watch_ends_on.present?
      watching_rel.where(stock_watch_batches: { starts_on: watch_starts_on, ends_on: watch_ends_on })
    else
      watching_rel.merge(StockWatchBatch.covering(StockWatchBatch.effective_watch_date))
    end
    watching_ids = watching_rel.distinct.pluck(:stock_id).to_set

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
