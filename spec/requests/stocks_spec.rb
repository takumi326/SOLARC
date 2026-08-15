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
      create_test_exit(stock: stock, shares: 10, actual_price: 1000, exit_reason: "売却")

      get stocks_path
      expect(response.body).to include("全決済済")
    end

    it "hides stocks without entries when not searching" do
      stock = create_test_stock(code: "3333", name: "ゼロエントリー銘柄")

      get stocks_path
      expect(response.body).not_to include("3333")
      expect(response.body).not_to include("ゼロエントリー銘柄")
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

    it "hides holdings summary when there are no remaining shares" do
      stock = create_test_stock
      create_test_entry(stock: stock, shares: 10, actual_price: 1000)
      create_test_exit(stock: stock, shares: 10, actual_price: 1000, exit_reason: "全部")

      get stock_path(stock)
      expect(response.body).not_to include("現在の保有")
    end

    it "shows current holding shares and average price on the timeline" do
      stock = create_test_stock
      create_test_entry(stock: stock, shares: 100, actual_price: 1234, entry_reason: "押し目")

      get stock_path(stock)
      expect(response.body).to include("現在の保有")
      expect(response.body).to include("100株")
      expect(response.body).to include("1234")
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

  describe "GET /stocks with filters" do
    it "shows watched stocks without entries" do
      stock = create_test_stock(code: "4444", name: "監視銘柄")
      create_test_watch_period(stock: stock)

      get stocks_path
      expect(response.body).to include("監視銘柄")
    end

    it "shows watched or entered stocks by default" do
      both = create_test_stock(code: "1212", name: "監視エントリー両方")
      create_test_watch_period(stock: both)
      create_test_entry(stock: both)
      watched_only = create_test_stock(code: "1313", name: "監視だけの銘柄")
      create_test_watch_period(stock: watched_only)
      entered_only = create_test_stock(code: "1414", name: "エントリーだけの銘柄")
      create_test_entry(stock: entered_only)

      get stocks_path
      expect(response.body).to include("監視エントリー両方")
      expect(response.body).to include("監視だけの銘柄")
      expect(response.body).to include("エントリーだけの銘柄")
    end

    it "filters to watching only" do
      watched = create_test_stock(code: "5555", name: "第五監視銘柄")
      create_test_watch_period(stock: watched)
      entered = create_test_stock(code: "6666", name: "第六エントリー銘柄")
      create_test_entry(stock: entered)

      get stocks_path, params: { watch: "1", entry: "0" }
      expect(response.body).to include("5555")
      expect(response.body).to include("第五監視銘柄")
      expect(response.body).not_to include("6666")
      expect(response.body).not_to include("第六エントリー銘柄")
    end

    it "filters to entered only" do
      watched = create_test_stock(code: "5555", name: "第五監視銘柄")
      create_test_watch_period(stock: watched)
      entered = create_test_stock(code: "6666", name: "第六エントリー銘柄")
      create_test_entry(stock: entered)

      get stocks_path, params: { watch: "0", entry: "1" }
      expect(response.body).to include("6666")
      expect(response.body).not_to include("5555")
    end

    it "shows no stocks when every checkbox is off" do
      stock = create_test_stock(code: "5555", name: "第五監視銘柄")
      create_test_watch_period(stock: stock)

      get stocks_path, params: { watch: "0", entry: "0", virtual: "0" }
      expect(response.body).not_to include("第五監視銘柄")
      expect(response.body).to include("監視・エントリー・仮想エントリーのいずれかを選んでください")
    end

    it "shows virtual entry stocks by default and under the 仮想エントリー checkbox" do
      stock = create_test_stock(code: "1111", name: "仮想のみ")
      create_test_entry(stock: stock, trade_type: "virtual", shares: 10)

      get stocks_path
      expect(response.body).to include("仮想のみ")

      get stocks_path, params: { watch: "0", entry: "0", virtual: "1" }
      expect(response.body).to include("仮想のみ")
    end

    it "hides virtual entry stocks when only エントリー is checked" do
      stock = create_test_stock(code: "1111", name: "仮想のみ")
      create_test_entry(stock: stock, trade_type: "virtual", shares: 10)

      get stocks_path, params: { watch: "0", entry: "1", virtual: "0" }
      expect(response.body).not_to include("仮想のみ")
    end

    it "hides real entry stocks when only 仮想エントリー is checked" do
      real = create_test_stock(code: "6666", name: "実エントリー銘柄")
      create_test_entry(stock: real)
      virtual = create_test_stock(code: "1111", name: "仮想のみ")
      create_test_entry(stock: virtual, trade_type: "virtual", shares: 10)

      get stocks_path, params: { watch: "0", entry: "0", virtual: "1" }
      expect(response.body).to include("仮想のみ")
      expect(response.body).not_to include("実エントリー銘柄")
    end

    it "shows エントリー中 and not 監視中 when holding even if watched" do
      watching = create_test_stock(code: "5555", name: "監視銘柄")
      create_test_watch_period(stock: watching, starts_on: Date.current, ends_on: Date.current)
      holding = create_test_stock(code: "6666", name: "エントリー銘柄")
      create_test_watch_period(stock: holding, starts_on: Date.current, ends_on: Date.current)
      create_test_entry(stock: holding, shares: 100)

      get stocks_path
      html = response.body
      watching_idx = html.index("5555")
      holding_idx = html.index("6666")
      watching_slice = html[watching_idx, 400]
      holding_slice = html[holding_idx, 400]
      expect(watching_slice).to include("監視中")
      expect(watching_slice).not_to include("エントリー中")
      expect(holding_slice).to include("エントリー中")
      expect(holding_slice).not_to include("監視中")
    end

    it "keeps stocks watched or entered within the selected period" do
      watched = create_test_stock(code: "1010", name: "期間監視")
      entered = create_test_stock(code: "2020", name: "期間エントリー")
      other = create_test_stock(code: "3030", name: "期間外")
      starts_on = Date.new(2026, 8, 10)
      ends_on = Date.new(2026, 8, 14)
      batch = StockWatchBatch.create!(imported_on: starts_on, starts_on: starts_on, ends_on: ends_on)
      StockWatchItem.create!(stock_watch_batch: batch, stock: watched, source_label: "ロング")
      create_test_entry(stock: entered, traded_at: Date.new(2026, 8, 12))
      create_test_entry(stock: other, traded_at: Date.new(2026, 7, 1))

      get stocks_path, params: {
        period_starts_on: starts_on.iso8601,
        period_ends_on: ends_on.iso8601
      }

      expect(response.body).to include("期間監視")
      expect(response.body).to include("期間エントリー")
      expect(response.body).not_to include("期間外")
    end

    it "keeps the submitted dates in the period inputs" do
      get stocks_path, params: {
        period_starts_on: "2026-08-10",
        period_ends_on: "2026-08-14"
      }

      expect(response.body).to include(%(name="period_starts_on"))
      expect(response.body).to include(%(name="period_ends_on"))
      expect(response.body).to include(%(type="date"))
      expect(response.body).to include(%(value="2026-08-10"))
      expect(response.body).to include(%(value="2026-08-14"))
      expect(response.body).not_to include("監視期間（開始）")
      expect(response.body).not_to include("監視期間（終了）")
      expect(response.body).not_to include("最近の監視期間")
      expect(response.body).not_to include("並び順")
      expect(response.body).not_to include("期間を解除")
      expect(response.body).not_to include("期間: ")
    end

    it "keeps a one-sided date in the period inputs" do
      get stocks_path, params: { period_starts_on: "2026-08-10" }

      expect(response.body).to include(%(value="2026-08-10"))
    end

    it "filters from the start date onward when only 開始日 is given" do
      inside = create_test_stock(code: "1010", name: "開始日以降")
      before = create_test_stock(code: "2020", name: "開始日より前")
      create_test_entry(stock: inside, traded_at: Date.new(2026, 8, 12))
      create_test_entry(stock: before, traded_at: Date.new(2026, 7, 1))

      get stocks_path, params: { period_starts_on: "2026-08-10" }

      expect(response.body).to include("開始日以降")
      expect(response.body).not_to include("開始日より前")
    end

    it "filters up to the end date when only 終了日 is given" do
      inside = create_test_stock(code: "1010", name: "終了日以前")
      later = create_test_stock(code: "2020", name: "終了日より後")
      create_test_entry(stock: inside, traded_at: Date.new(2026, 7, 1))
      create_test_entry(stock: later, traded_at: Date.new(2026, 8, 15))

      get stocks_path, params: { period_ends_on: "2026-08-14" }

      expect(response.body).to include("終了日以前")
      expect(response.body).not_to include("終了日より後")
    end

    it "keeps an inverted range in the inputs without filtering by it" do
      stock = create_test_stock(code: "1010", name: "逆転期間銘柄")
      create_test_entry(stock: stock, traded_at: Date.new(2026, 7, 1))

      get stocks_path, params: {
        period_starts_on: "2026-08-14",
        period_ends_on: "2026-08-10"
      }

      expect(response.body).to include(%(value="2026-08-14"))
      expect(response.body).to include(%(value="2026-08-10"))
      expect(response.body).to include("逆転期間銘柄")
    end

    it "filters watch periods from the start date onward" do
      inside = create_test_stock(code: "3030", name: "以降監視")
      before = create_test_stock(code: "4040", name: "以前監視")
      inside_batch = StockWatchBatch.create!(imported_on: Date.new(2026, 8, 10), starts_on: Date.new(2026, 8, 10), ends_on: Date.new(2026, 8, 14))
      before_batch = StockWatchBatch.create!(imported_on: Date.new(2026, 7, 1), starts_on: Date.new(2026, 7, 1), ends_on: Date.new(2026, 7, 3))
      StockWatchItem.create!(stock_watch_batch: inside_batch, stock: inside, source_label: "ロング")
      StockWatchItem.create!(stock_watch_batch: before_batch, stock: before, source_label: "ロング")

      get stocks_path, params: { period_starts_on: "2026-08-10", watch: "1", entry: "0", virtual: "0" }

      expect(response.body).to include("以降監視")
      expect(response.body).not_to include("以前監視")
    end

    it "filters to watched only within the selected period" do
      watched = create_test_stock(code: "4141", name: "期間監視だけ")
      entered = create_test_stock(code: "5151", name: "期間エントリーだけ")
      starts_on = Date.new(2026, 8, 10)
      ends_on = Date.new(2026, 8, 14)
      batch = StockWatchBatch.create!(imported_on: starts_on, starts_on: starts_on, ends_on: ends_on)
      StockWatchItem.create!(stock_watch_batch: batch, stock: watched, source_label: "ロング")
      create_test_entry(stock: entered, traded_at: Date.new(2026, 8, 11))

      get stocks_path, params: {
        period_starts_on: starts_on.iso8601,
        period_ends_on: ends_on.iso8601,
        watch: "1",
        entry: "0"
      }

      expect(response.body).to include("期間監視だけ")
      expect(response.body).not_to include("期間エントリーだけ")
    end

    it "filters to entered only within the selected period" do
      watched = create_test_stock(code: "4040", name: "監視だけ")
      entered = create_test_stock(code: "5050", name: "エントリーだけ")
      starts_on = Date.new(2026, 8, 10)
      ends_on = Date.new(2026, 8, 14)
      batch = StockWatchBatch.create!(imported_on: starts_on, starts_on: starts_on, ends_on: ends_on)
      StockWatchItem.create!(stock_watch_batch: batch, stock: watched, source_label: "ロング")
      create_test_entry(stock: entered, traded_at: Date.new(2026, 8, 11))

      get stocks_path, params: {
        period_starts_on: starts_on.iso8601,
        period_ends_on: ends_on.iso8601,
        watch: "0",
        entry: "1"
      }

      expect(response.body).to include("エントリーだけ")
      expect(response.body).not_to include("監視だけ")
    end

    it "sorts watched stocks first then by code within the selected period" do
      watched = create_test_stock(code: "2222", name: "期間監視")
      entered = create_test_stock(code: "1111", name: "期間エントリー")
      starts_on = Date.new(2026, 8, 10)
      ends_on = Date.new(2026, 8, 14)
      batch = StockWatchBatch.create!(imported_on: starts_on, starts_on: starts_on, ends_on: ends_on)
      StockWatchItem.create!(stock_watch_batch: batch, stock: watched, source_label: "ロング")
      create_test_entry(stock: entered, traded_at: Date.new(2026, 8, 11))

      get stocks_path, params: {
        period_starts_on: starts_on.iso8601,
        period_ends_on: ends_on.iso8601
      }

      expect(response.body.index("期間監視")).to be < response.body.index("期間エントリー")
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
