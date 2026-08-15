# frozen_string_literal: true

require "rails_helper"

RSpec.describe StockTimelineBuilder do
  let(:stock) { create_test_stock }

  describe ".build" do
    it "returns sorted timeline rows and current line" do
      create_test_entry(stock: stock, entry_reason: "entry1", traded_at: 2.days.ago.to_date)
      create_test_line_change(stock: stock, changed_on: Date.current, stop_loss: 1000)

      result = described_class.build(stock: stock, trade_type: "real", judgment_type: "human")
      expect(result[:rows].map(&:kind)).to include("entry", "line_change")
      expect(result[:current_line].stop_loss).to eq(1000)
      expect(result[:rows].first.kind).to eq("line_change")
    end

    it "orders same-day rows as exit, line change, then entry" do
      day = Date.current
      create_test_entry(stock: stock, entry_reason: "同日", traded_at: day)
      create_test_line_change(stock: stock, changed_on: day, stop_loss: 900)
      create_test_exit(stock: stock, traded_at: day, shares: 100, actual_price: 1000)

      result = described_class.build(stock: stock, trade_type: "real", judgment_type: "human")
      same_day = result[:rows].select { |r| r.sort_on.to_s == day.to_s }
      expect(same_day.map(&:kind)).to eq(%w[exit line_change entry])
    end

    it "returns remaining shares and weighted average entry price" do
      create_test_entry(stock: stock, shares: 100, actual_price: 1000, traded_at: 3.days.ago.to_date)
      create_test_entry(stock: stock, shares: 50, actual_price: 1300, traded_at: 2.days.ago.to_date)
      create_test_exit(stock: stock, traded_at: Date.current, shares: 50, actual_price: 1400)

      result = described_class.build(stock: stock, trade_type: "real", judgment_type: "human")
      expect(result[:position][:shares]).to eq(100)
      expect(result[:position][:avg_price]).to eq(BigDecimal("1100"))
    end

    it "starts a new position after a full exit" do
      create_test_entry(stock: stock, shares: 100, actual_price: 3480, traded_at: Date.new(2026, 6, 26))
      create_test_exit(stock: stock, traded_at: Date.new(2026, 8, 14), shares: 100, actual_price: 2222)
      create_test_entry(stock: stock, shares: 10_000, actual_price: 200, traded_at: Date.new(2026, 8, 15))

      result = described_class.build(stock: stock, trade_type: "real", judgment_type: "human")
      expect(result[:position][:shares]).to eq(10_000)
      expect(result[:position][:avg_price]).to eq(BigDecimal("200"))
      expect(stock.positions.count).to eq(2)
    end

    it "does not use expected_price for average acquisition" do
      create_test_entry(stock: stock, shares: 100, actual_price: 1000, expected_price: 9999, traded_at: Date.current)

      result = described_class.build(stock: stock, trade_type: "real", judgment_type: "human")
      expect(result[:position][:avg_price]).to eq(BigDecimal("1000"))
    end

    it "does not use line changes from a previous closed position" do
      create_test_entry(stock: stock, shares: 100, actual_price: 3480, traded_at: Date.new(2026, 6, 26))
      create_test_line_change(
        stock: stock,
        changed_on: Date.new(2026, 8, 14),
        stop_loss: 200,
        target_price: 300
      )
      create_test_exit(stock: stock, traded_at: Date.new(2026, 8, 14), shares: 100, actual_price: 2222)
      create_test_entry(stock: stock, shares: 10_000, actual_price: 200, traded_at: Date.new(2026, 8, 15))

      result = described_class.build(stock: stock, trade_type: "real", judgment_type: "human")
      expect(result[:current_line]).to be_nil
    end
  end
end

RSpec.describe StockTradeEventsQuery do
  let(:stock) { create_test_stock }

  describe ".call" do
    it "returns trade events for real human axis" do
      create_test_entry(stock: stock, entry_reason: "query test")
      create_test_line_change(stock: stock, changed_on: Date.current, stop_loss: 1000)
      result = described_class.call(trade_type: "real", judgment_type: "human", event_kind: "all")
      expect(result.rows.map(&:kind)).to eq([ "entry" ])
    end
  end
end
