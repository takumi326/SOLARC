# frozen_string_literal: true

module StockTestHelpers
  def create_test_stock(code: "7203", name: "トヨタ", industry_name: "輸送用機器")
    industry = Industry.find_or_create_by!(name: industry_name)
    Stock.create!(code: code, name: name, industry: industry)
  end

  def create_test_entry(stock:, **attrs)
    traded_at = attrs.delete(:traded_at) || Date.current
    shares = attrs.delete(:shares)
    TradeEventRegistrar.new(stock: stock).call(
      kind: :entry,
      executed_at: Time.zone.local(traded_at.year, traded_at.month, traded_at.day, 12, 0, 0),
      trade_type: attrs.delete(:trade_type) || "real",
      judgment_type: attrs.delete(:judgment_type) || "human",
      ai_script_id: attrs.delete(:ai_script_id),
      quantity: shares || 100,
      entry_reason: attrs.delete(:entry_reason) || "テストエントリー",
      actual_price: attrs.delete(:actual_price) || 1000,
      **attrs
    )
  end

  def create_test_exit(stock:, **attrs)
    traded_at = attrs.delete(:traded_at) || Date.current
    shares = attrs.delete(:shares)
    TradeEventRegistrar.new(stock: stock).call(
      kind: :exit,
      executed_at: Time.zone.local(traded_at.year, traded_at.month, traded_at.day, 15, 0, 0),
      trade_type: attrs.delete(:trade_type) || "real",
      judgment_type: attrs.delete(:judgment_type) || "human",
      ai_script_id: attrs.delete(:ai_script_id),
      quantity: shares,
      exit_reason: attrs.delete(:exit_reason) || "テストイグジット",
      actual_price: attrs.delete(:actual_price) || 1000,
      **attrs
    )
  end

  def create_test_line_change(stock:, **attrs)
    changed_on = attrs.delete(:changed_on) || Date.current
    TradeEventRegistrar.new(stock: stock).call(
      kind: :line_change,
      executed_at: Time.zone.local(changed_on.year, changed_on.month, changed_on.day, 13, 0, 0),
      trade_type: attrs.delete(:trade_type) || "real",
      judgment_type: attrs.delete(:judgment_type) || "human",
      ai_script_id: attrs.delete(:ai_script_id),
      stop_loss: attrs.delete(:stop_loss),
      take_profit: attrs.delete(:target_price) || attrs.delete(:take_profit),
      reason: attrs.delete(:reason),
      **attrs
    )
  end

  def create_test_watch_period(stock:, starts_on: Date.current, ends_on: Date.current + 4, source_label: "手動")
    batch = StockWatchBatch.create!(
      imported_on: Date.current,
      starts_on: starts_on,
      ends_on: ends_on
    )
    StockWatchItem.create!(stock_watch_batch: batch, stock: stock, source_label: source_label)
    StockWatchBatch.sync_watched_flags!
    batch
  end
end

RSpec.configure do |config|
  config.include StockTestHelpers
end
