require "rails_helper"

RSpec.describe "StockTrades", type: :request do
  describe "GET /stocks/trades/:mode" do
    it "shows real trades list" do
      stock = create_test_stock
      create_test_entry(stock: stock, entry_reason: "一覧用")

      get stock_trades_path(mode: "real")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("実取引一覧")
      expect(response.body).to include("一覧用")
    end
  end
end
