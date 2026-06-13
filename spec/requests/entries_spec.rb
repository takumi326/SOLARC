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
          traded_at: Date.current.iso8601
        }
      }
      expect(response).to redirect_to(stock_path(stock, trade_type: "real", judgment_type: "human"))
      expect(Entry.count).to eq(1)
    end
  end

  describe "GET /entries/:id" do
    it "shows entry" do
      entry = create_test_entry(stock: stock)
      get entry_path(entry)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("エントリー（買い）詳細")
    end
  end

  describe "DELETE /entries/:id" do
    it "destroys entry" do
      entry = create_test_entry(stock: stock)
      delete entry_path(entry)
      expect(response).to redirect_to(stock_path(stock, trade_type: "real", judgment_type: "human"))
      expect(Entry.exists?(entry.id)).to be(false)
    end
  end
end
