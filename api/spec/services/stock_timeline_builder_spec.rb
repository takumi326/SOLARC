# frozen_string_literal: true

require "rails_helper"

RSpec.describe StockTimelineBuilder do
  let(:stock) { create_test_stock }

  describe ".build" do
    it "returns sorted timeline rows and current line" do
      entry = create_test_entry(stock: stock, entry_reason: "entry1", traded_at: 2.days.ago.to_date)
      LineChange.create!(
        stock: stock,
        trade_type: "real",
        judgment_type: "human",
        changed_on: Date.current,
        stop_loss: 1000
      )

      result = described_class.build(stock: stock, trade_type: "real", judgment_type: "human")
      expect(result[:rows].map(&:kind)).to include("entry", "line_change")
      expect(result[:current_line].stop_loss).to eq(1000)
      expect(result[:rows].first.kind).to eq("line_change")
    end
  end
end

RSpec.describe StockTradeEventsQuery do
  let(:stock) { create_test_stock }

  describe ".call" do
    it "returns trade events for real human axis" do
      create_test_entry(stock: stock, entry_reason: "query test")
      result = described_class.call(trade_type: "real", judgment_type: "human", event_kind: "all")
      expect(result.rows.size).to eq(1)
      expect(result.rows.first.kind).to eq("entry")
    end
  end
end
