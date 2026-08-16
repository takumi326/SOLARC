# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LineChanges", type: :request do
  let(:stock) { create_test_stock }

  it "creates a line change nested under line_change params" do
    # エントリーは正午固定。ライン変更は「現在時刻」で記録されるため、午前だと建玉検索に失敗する
    create_test_entry(stock: stock, shares: 100, actual_price: 1000, traded_at: Date.current - 1)

    post line_changes_path, params: {
      line_change: {
        stock_id: stock.id,
        trade_type: "real",
        judgment_type: "human",
        changed_on: Date.current.iso8601,
        stop_loss: 11,
        target_price: 22,
        reason: "切り上げ"
      }
    }

    expect(response).to redirect_to(stock_path(stock, trade_type: "real", judgment_type: "human"))
    expect(TradeEvent.line_change.count).to eq(1)
  end
end
