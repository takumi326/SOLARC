require "rails_helper"

RSpec.describe "StockTrades", type: :request do
  describe "GET /stocks/trades/:mode" do
    it "shows real trades list" do
      stock = create_test_stock
      create_test_entry(stock: stock, entry_reason: "一覧用")
      create_test_line_change(
        stock: stock,
        changed_on: Date.current,
        stop_loss: 1000,
        reason: "ライン変更理由"
      )

      get stock_trades_path(mode: "real")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("実取引一覧")
      expect(response.body).to include("一覧用")
      expect(response.body).not_to include("ライン変更")
    end

    it "filters real trades to the previous weekday range" do
      travel_to Time.zone.local(2026, 8, 29, 10, 0, 0) do
        last_week_stock = create_test_stock(code: "7203", name: "トヨタ")
        this_week_stock = create_test_stock(code: "6758", name: "ソニー")
        create_test_entry(stock: last_week_stock, traded_at: Date.new(2026, 8, 19), entry_reason: "前週エントリー")
        create_test_entry(stock: this_week_stock, traded_at: Date.new(2026, 8, 26), entry_reason: "今週エントリー")

        get stock_trades_path(mode: "real")
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("前週で絞り込み")
        expect(response.body).to include("from=2026-08-17")
        expect(response.body).to include("to=2026-08-21")

        get stock_trades_path(mode: "real", from: "2026-08-17", to: "2026-08-21")
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("前週エントリー")
        expect(response.body).not_to include("今週エントリー")
      end
    end

    it "shows realized pl for the filtered date range" do
      travel_to Time.zone.local(2026, 8, 29, 10, 0, 0) do
        last_week = create_test_stock(code: "7203", name: "トヨタ")
        this_week = create_test_stock(code: "6758", name: "ソニー")
        create_test_entry(stock: last_week, traded_at: Date.new(2026, 8, 10), shares: 100, actual_price: 1000)
        create_test_exit(stock: last_week, traded_at: Date.new(2026, 8, 19), shares: 100, actual_price: 1111, exit_reason: "前週決済")
        create_test_entry(stock: this_week, traded_at: Date.new(2026, 8, 24), shares: 100, actual_price: 1000)
        create_test_exit(stock: this_week, traded_at: Date.new(2026, 8, 26), shares: 100, actual_price: 900, exit_reason: "今週決済")

        get stock_trades_path(mode: "real")
        expect(response.body).to match(/id="trades-pl-total"[^>]*>\s*1,100/)

        get stock_trades_path(mode: "real", from: "2026-08-17", to: "2026-08-21")
        expect(response.body).to match(/id="trades-pl-total"[^>]*>\s*11,100/)
        expect(response.body).to include("前週決済")
        expect(response.body).not_to include("今週決済")
      end
    end
  end
end
