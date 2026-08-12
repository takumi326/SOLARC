require "rails_helper"

RSpec.describe "Stocks", type: :request do
  describe "GET /stocks" do
    it "shows stocks with any entry" do
      stock = create_test_stock
      create_test_entry(stock: stock)

      get stocks_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("株一覧")
      expect(response.body).to include(stock.name)
    end

    it "shows stocks with virtual entry only" do
      stock = create_test_stock(code: "1111", name: "仮想のみ")
      create_test_entry(stock: stock, trade_type: "virtual", shares: 10)

      get stocks_path
      expect(response.body).to include("仮想のみ")
    end

    it "shows stocks even when fully exited" do
      stock = create_test_stock(code: "2222", name: "全決済済")
      create_test_entry(stock: stock, shares: 10)
      StockExit.create!(
        stock: stock,
        trade_type: "real",
        judgment_type: "human",
        exit_reason: "売却",
        traded_at: Date.current,
        shares: 10,
        actual_price: 1000
      )

      get stocks_path
      expect(response.body).to include("全決済済")
    end

    it "hides stocks without entries when not searching" do
      stock = create_test_stock(code: "3333", name: "未エントリー")

      get stocks_path
      expect(response.body).not_to include("未エントリー")
    end

    it "searches by query" do
      stock = create_test_stock(code: "9984", name: "ソフトバンクG")
      get stocks_path, params: { q: "9984" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ソフトバンクG")
    end
  end

  describe "GET /stocks/:id" do
    it "shows stock detail with timeline" do
      stock = create_test_stock
      stock.update!(memo: "テストメモ")
      create_test_entry(stock: stock, entry_reason: "買い理由")

      get stock_path(stock)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(stock.name)
      expect(response.body).to include("銘柄設定")
      expect(response.body).to include("テストメモ")
      expect(response.body).to include("編集")
      expect(response.body).not_to include("メモを保存")
      expect(response.body).to include("取引タイムライン")
      expect(response.body).to include("買い理由")
    end

    it "shows watch periods from imported watchlists" do
      stock = create_test_stock
      create_test_watch_period(
        stock: stock,
        starts_on: Date.new(2026, 8, 17),
        ends_on: Date.new(2026, 8, 21),
        source_label: "ロング_押し目"
      )

      get stock_path(stock)
      expect(response.body).to include("監視期間")
      expect(response.body).to include("8/17〜8/21")
      expect(response.body).to include(%(href="#{new_stock_stock_watch_period_path(stock)}"))
    end
  end

  describe "GET /stocks/:id/edit" do
    it "shows memo edit form" do
      stock = create_test_stock

      get edit_stock_path(stock)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("銘柄設定")
      expect(response.body).to include("保存")
    end
  end

  describe "PATCH /stocks/:id" do
    it "updates memo and redirects to stock detail" do
      stock = create_test_stock
      patch stock_path(stock), params: { stock: { memo: "メモ更新" } }
      expect(response).to redirect_to(stock_path(stock, trade_type: "real", judgment_type: "human"))
      expect(stock.reload.memo).to eq("メモ更新")
    end
  end

  describe "GET /stocks with filters" do
    it "shows watched stocks without entries" do
      stock = create_test_stock(code: "4444", name: "監視銘柄")
      create_test_watch_period(stock: stock)

      get stocks_path
      expect(response.body).to include("監視銘柄")
    end

    it "filters to watching only" do
      watched = create_test_stock(code: "5555", name: "監視のみ")
      create_test_watch_period(stock: watched)
      entered = create_test_stock(code: "6666", name: "エントリーのみ")
      create_test_entry(stock: entered)

      get stocks_path, params: { filter: "watching" }
      expect(response.body).to include("監視のみ")
      expect(response.body).not_to include("エントリーのみ")
    end

    it "filters by industry" do
      industry = Industry.find_or_create_by!(name: "フィルタ業種")
      stock = create_test_stock(code: "7777", name: "業種フィルタ", industry_name: "フィルタ業種")
      create_test_watch_period(stock: stock)
      other = create_test_stock(code: "8888", name: "別業種", industry_name: "その他")
      create_test_watch_period(stock: other)

      get stocks_path, params: { industry_id: industry.id }
      expect(response.body).to include("業種フィルタ")
      expect(response.body).not_to include("別業種")
    end
  end

  describe "PATCH /stocks/:id with industry" do
    it "updates industry and memo" do
      stock = create_test_stock
      industry = Industry.find_or_create_by!(name: "変更後業種")

      patch stock_path(stock), params: { stock: { industry_id: industry.id, memo: "x" } }
      stock.reload
      expect(stock.industry_id).to eq(industry.id)
      expect(stock.memo).to eq("x")
    end
  end

  describe "GET /stocks/:id/timeline" do
    it "redirects to stock detail with timeline params" do
      stock = create_test_stock

      get timeline_stock_path(stock, trade_type: "real", judgment_type: "human")
      expect(response).to redirect_to(stock_path(stock, trade_type: "real", judgment_type: "human"))
    end
  end

  describe "GET /stocks" do
    it "shows import shortcuts in the header" do
      get stocks_path
      expect(response.body).to include("銘柄取込")
      expect(response.body).to include("監視銘柄取込")
      expect(response.body).to include(%(href="#{new_import_stocks_path}"))
      expect(response.body).to include(%(href="#{new_stock_watchlist_path}"))
    end
  end

  describe "GET /stocks/import" do
    it "shows the CSV import form" do
      get new_import_stocks_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("銘柄取込")
      expect(response.body).to include("CSVを選択")
      expect(response.body).to include("JPX日経400")
      expect(response.body).to include("https://indexes.nikkei.co.jp/nkave/index/profile?idx=jpxnk400")
    end
  end

  describe "POST /stocks/import" do
    it "imports CSV" do
      csv = <<~CSV
        銘柄名,コード,業種
        ニッスイ,1332,水産・農林業
      CSV
      file = Rack::Test::UploadedFile.new(StringIO.new(csv), "text/csv", original_filename: "jpx400.csv")

      post import_stocks_path, params: { file: file }
      expect(response).to redirect_to(stocks_path)
      expect(Stock.find_by(code: "1332")&.name).to eq("ニッスイ")
    end
  end
end
