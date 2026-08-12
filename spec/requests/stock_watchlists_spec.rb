# frozen_string_literal: true

require "rails_helper"

RSpec.describe "StockWatchlists", type: :request do
  it "shows the import form with next weekday defaults" do
    travel_to Time.zone.local(2026, 8, 8, 10, 0, 0) do
      get new_stock_watchlist_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("監視銘柄リストを取込")
      expect(response.body).to include("TXTを選択")
      expect(response.body).to include("株一覧へ戻る")
      expect(response.body).to include(%(href="#{stocks_path}"))
      expect(response.body).not_to include("ルーチンへ戻る")
      expect(response.body).to include('value="2026-08-08"')
      expect(response.body).to include('value="2026-08-10"')
      expect(response.body).to include('value="2026-08-14"')
    end
  end

  it "defaults imported_on to the routine date when given" do
    travel_to Time.zone.local(2026, 8, 13, 7, 0, 0) do
      get new_stock_watchlist_path(date: "2026-08-09")
      expect(response.body).to include('name="imported_on" id="imported_on" value="2026-08-09"')
      expect(response.body).to include('value="2026-08-10"')
      expect(response.body).to include('value="2026-08-14"')
    end
  end

  it "imports files and redirects to the routine page" do
    create_test_stock(code: "2871", name: "ニチレイ")
    create_test_stock(code: "5444", name: "大和工業")

    tempfile = Tempfile.new([ "ロング_押し目_2cf6d", ".txt" ])
    tempfile.write("TSE:2871,TSE:5444")
    tempfile.rewind
    file = Rack::Test::UploadedFile.new(tempfile.path, "text/plain", original_filename: "ロング_押し目_2cf6d.txt")

    travel_to Time.zone.local(2026, 8, 8, 10, 0, 0) do
      expect {
        post stock_watchlists_path, params: {
          imported_on: "2026-08-08",
          starts_on: "2026-08-10",
          ends_on: "2026-08-14",
          files: [ file ]
        }
      }.to change(StockWatchBatch, :count).by(1)

      expect(response).to redirect_to(daily_routine_path(date: "2026-08-08"))
      follow_redirect!
      expect(response.body).to include("✓ 完了")
      expect(response.body).to include("監視銘柄リストを取り込んでいる")
    end
  ensure
    tempfile.close!
  end
end
