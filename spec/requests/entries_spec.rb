require "rails_helper"

RSpec.describe "Entries", type: :request do
  let(:stock) { create_test_stock }

  describe "POST /entries" do
    it "creates entry and redirects to timeline" do
      post entries_path, params: {
        entry: {
          stock_id: stock.id,
          trade_type: "real",
          judgment_type: "human",
          entry_reason: "買い",
          shares: 10,
          actual_price: 1000,
          traded_at: Date.current.iso8601
        }
      }
      expect(response).to redirect_to(stock_path(stock, trade_type: "real", judgment_type: "human"))
      expect(TradeEvent.entry.count).to eq(1)
    end

    it "rejects when both expected_price and actual_price are blank" do
      post entries_path, params: {
        entry: {
          stock_id: stock.id,
          trade_type: "real",
          judgment_type: "human",
          entry_reason: "買い",
          shares: 10
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("予定価格か約定価格のどちらかを入力してください")
      expect(TradeEvent.entry.count).to eq(0)
    end

    it "rejects actual_price without traded_at" do
      post entries_path, params: {
        entry: {
          stock_id: stock.id,
          trade_type: "real",
          judgment_type: "human",
          entry_reason: "買い",
          shares: 10,
          actual_price: 1000
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("約定するときは株数・約定価格・約定日をセットで入力してください")
      expect(TradeEvent.entry.count).to eq(0)
    end

    it "rejects traded_at without actual_price" do
      post entries_path, params: {
        entry: {
          stock_id: stock.id,
          trade_type: "real",
          judgment_type: "human",
          entry_reason: "買い",
          shares: 10,
          traded_at: Date.current.iso8601
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("約定するときは株数・約定価格・約定日をセットで入力してください")
      expect(TradeEvent.entry.count).to eq(0)
    end

    it "rejects actual_price and traded_at without shares" do
      post entries_path, params: {
        entry: {
          stock_id: stock.id,
          trade_type: "real",
          judgment_type: "human",
          entry_reason: "買い",
          actual_price: 1000,
          traded_at: Date.current.iso8601
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("約定するときは株数・約定価格・約定日をセットで入力してください")
      expect(TradeEvent.entry.count).to eq(0)
    end

    it "rejects non-numeric actual_price" do
      post entries_path, params: {
        entry: {
          stock_id: stock.id,
          trade_type: "real",
          judgment_type: "human",
          entry_reason: "買い",
          shares: 10,
          actual_price: "aaaa",
          traded_at: Date.current.iso8601
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("は数値で入力してください")
      expect(TradeEvent.entry.count).to eq(0)
    end

    it "rejects a future traded_at" do
      post entries_path, params: {
        entry: {
          stock_id: stock.id,
          trade_type: "real",
          judgment_type: "human",
          entry_reason: "買い",
          shares: 10,
          actual_price: 1000,
          traded_at: (Date.current + 1).iso8601
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("今日以前")
      expect(TradeEvent.entry.count).to eq(0)
    end
  end

  describe "GET /entries/:id" do
    it "shows entry" do
      entry = create_test_entry(stock: stock)
      get entry_path(entry)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("エントリー詳細")
    end
  end

  describe "DELETE /entries/:id" do
    it "destroys entry" do
      entry = create_test_entry(stock: stock)
      delete entry_path(entry)
      expect(response).to redirect_to(stock_path(stock, trade_type: "real", judgment_type: "human"))
      expect(TradeEvent.exists?(entry.id)).to be(false)
    end
  end
end
