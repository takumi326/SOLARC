require "rails_helper"

RSpec.describe "Stocks", type: :request do
  describe "GET /stocks" do
    it "shows stocks with an open real position" do
      stock = create_test_stock
      create_test_entry(stock: stock)

      get stocks_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("株一覧")
      expect(response.body).to include(stock.name)
      expect(response.body).to include("エントリー中")
    end

    it "hides currently watched stocks that are not holding" do
      stock = create_test_stock(code: "4444", name: "期間だけの監視")
      create_test_watch_period(stock: stock)

      get stocks_path
      expect(response.body).not_to include("4444")
      expect(response.body).not_to include("期間だけの監視")
    end

    it "hides virtual holding stocks that are not holding real shares" do
      stock = create_test_stock(code: "1111", name: "仮想のみ")
      create_test_entry(stock: stock, trade_type: "virtual", shares: 10)

      get stocks_path
      expect(response.body).not_to include("仮想のみ")
    end

    it "hides fully exited stocks" do
      stock = create_test_stock(code: "2222", name: "全決済済")
      create_test_entry(stock: stock, shares: 10)
      create_test_exit(stock: stock, shares: 10, actual_price: 1000, exit_reason: "売却")

      get stocks_path
      expect(response.body).not_to include("全決済済")
    end

    it "hides stocks that are not watched or holding" do
      create_test_stock(code: "3333", name: "ゼロエントリー銘柄")

      get stocks_path
      expect(response.body).not_to include("3333")
      expect(response.body).not_to include("ゼロエントリー銘柄")
    end

    it "does not show a search field" do
      get stocks_path
      expect(response.body).not_to include("コード・銘柄名で検索")
    end

    it "shows stocks in the requested watch period from the daily routine" do
      watched = create_test_stock(code: "4444", name: "期間監視")
      other_period = create_test_stock(code: "5555", name: "別期間")
      create_test_watch_period(stock: watched, starts_on: Date.new(2026, 8, 10), ends_on: Date.new(2026, 8, 14))
      create_test_watch_period(stock: other_period, starts_on: Date.new(2026, 8, 17), ends_on: Date.new(2026, 8, 21))

      get stocks_path(starts_on: "2026-08-10", ends_on: "2026-08-14")
      expect(response.body).to include("監視銘柄（8/10〜8/14）")
      expect(response.body).to include("期間監視")
      expect(response.body).to include("監視中")
      expect(response.body).not_to include("別期間")
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
      expect(response.body).to include("チャート")
      expect(response.body).not_to include("TradingView で開く")
      expect(response.body).not_to include("観察履歴")
    end

    it "shows エントリー中 when holding shares and 監視中 only during an active watch period" do
      stock = create_test_stock
      create_test_watch_period(
        stock: stock,
        starts_on: Date.new(2026, 8, 10),
        ends_on: Date.new(2026, 8, 14)
      )
      create_test_entry(stock: stock, shares: 100, actual_price: 3480)

      get stock_path(stock)
      expect(response.body).to include("エントリー中")
      expect(response.body).not_to include("監視中")
    end

    it "shows 監視中 when today is in a watch period" do
      stock = create_test_stock
      create_test_watch_period(
        stock: stock,
        starts_on: Date.current,
        ends_on: Date.current
      )

      get stock_path(stock)
      expect(response.body).to include("監視中")
      expect(response.body).not_to include("エントリー中")
    end

    it "hides open holding label when there are no remaining shares" do
      stock = create_test_stock
      create_test_entry(stock: stock, shares: 10, actual_price: 1000)
      create_test_exit(stock: stock, shares: 10, actual_price: 1000, exit_reason: "全部")

      get stock_path(stock)
      expect(response.body).not_to include("建玉（保有中）")
      expect(response.body).to include("建玉（決済済）")
    end

    it "shows current holding shares and average price on the timeline" do
      stock = create_test_stock
      create_test_entry(stock: stock, shares: 100, actual_price: 1234, entry_reason: "押し目")

      get stock_path(stock)
      expect(response.body).to include("建玉（保有中）")
      expect(response.body).to include("100株")
      expect(response.body).to include("1,234")
      expect(response.body).to include("株数")
      expect(response.body).to include("価格")
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

  describe "GET /stocks/lookup" do
    it "returns matching stocks as JSON" do
      stock = create_test_stock(code: "9984", name: "ソフトバンクG")

      get lookup_stocks_path, params: { q: "9984" }, as: :json
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body).to include(hash_including(
        "code" => "9984",
        "name" => "ソフトバンクG",
        "url" => stock_path(stock),
        "holding" => false,
        "virtual_holding" => false,
        "watching" => false
      ))
    end

    it "includes holding and watching flags" do
      holding = create_test_stock(code: "6501", name: "日立製作所")
      watching = create_test_stock(code: "6503", name: "三菱電機")
      create_test_entry(stock: holding)
      create_test_watch_period(stock: watching)

      get lookup_stocks_path, params: { q: "650" }, as: :json
      expect(response.parsed_body).to include(
        hash_including("code" => "6501", "holding" => true, "watching" => false),
        hash_including("code" => "6503", "holding" => false, "watching" => true)
      )
    end

    it "orders by エントリー中, 監視中, 仮想エントリー中, then others" do
      other = create_test_stock(code: "1000", name: "その他")
      virtual = create_test_stock(code: "1001", name: "仮想")
      watching = create_test_stock(code: "1002", name: "監視")
      holding = create_test_stock(code: "1099", name: "実保有")
      create_test_entry(stock: holding)
      create_test_watch_period(stock: watching)
      create_test_entry(stock: virtual, trade_type: "virtual")

      get lookup_stocks_path, params: { q: "10" }, as: :json
      codes = response.parsed_body.map { |row| row["code"] }
      expect(codes).to eq(%w[1099 1002 1001 1000])
    end

    it "returns an empty list when query is blank" do
      create_test_stock(code: "9984", name: "ソフトバンクG")

      get lookup_stocks_path, params: { q: "" }, as: :json
      expect(response.parsed_body).to eq([])
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
      expect(response.body).to include("需給/決算を分析")
      expect(response.body).to include(%(href="#{stock_fundamentals_path}"))
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
