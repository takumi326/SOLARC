# frozen_string_literal: true

require "rails_helper"

RSpec.describe "DailyRoutines", type: :request do
  describe "GET /daily-routine" do
    it "shows weekday slots on a weekday" do
      travel_to Time.zone.local(2026, 8, 11, 10, 0, 0) do
        get daily_routine_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("ルーチン")
        expect(response.body).to include("平日朝")
        expect(response.body).to include("平日夜")
        expect(response.body).not_to include(">休日</h3>")
        expect(response.body).to include("この日を休みにする")
        expect(DailyRoutineItem.for_owner("development").count).to eq(24)
      end
    end

    it "starts showing the month end card three days before the last day" do
      create(:expense, start_month: Date.new(2026, 7, 1), imported_at: Time.zone.local(2026, 7, 31))

      travel_to Time.zone.local(2026, 8, 28, 10, 0, 0) do
        get daily_routine_path
        expect(response.body).not_to include(">8月末</h3>")
      end

      travel_to Time.zone.local(2026, 8, 29, 10, 0, 0) do
        get daily_routine_path
        expect(response.body).to include(">8月末</h3>")
        expect(response.body).to include("完了条件：8月分の支払いを取り込んでいる")
        expect(response.body).to include(%(href="#{finance_import_path(prompt_month: "2026-08")}"))
        expect(response.body).to include("カード明細を用意する")
      end
    end

    it "keeps showing the month end card until the month is imported" do
      travel_to Time.zone.local(2026, 8, 11, 10, 0, 0) do
        get daily_routine_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(">7月末</h3>")
        expect(response.body).to include("完了条件：7月分の支払いを取り込んでいる")
      end
    end

    it "shows one card per month that is still not imported" do
      travel_to Time.zone.local(2026, 8, 31, 10, 0, 0) do
        get daily_routine_path

        expect(response.body).to include(">7月末</h3>")
        expect(response.body).to include(">8月末</h3>")
        expect(response.body).to include("完了条件：7月分の支払いを取り込んでいる")
        expect(response.body).to include("完了条件：8月分の支払いを取り込んでいる")
      end
    end

    it "shows the month end card as done on the day of the import" do
      create(:expense, start_month: Date.new(2026, 7, 1), imported_at: Time.zone.local(2026, 8, 11, 9, 0, 0))

      travel_to Time.zone.local(2026, 8, 11, 10, 0, 0) do
        get daily_routine_path

        expect(response.body).to include(">7月末</h3>")
        expect(response.body).to include("✓ 完了")
      end
    end

    it "hides an overdue month end card from the next day of the import" do
      create(:expense, start_month: Date.new(2026, 7, 1), imported_at: Time.zone.local(2026, 8, 11, 9, 0, 0))

      travel_to Time.zone.local(2026, 8, 12, 10, 0, 0) do
        get daily_routine_path

        expect(response.body).not_to include("月末</h3>")
      end
    end

    it "shows imported month history from the import day through Friday" do
      create(:expense, start_month: Date.new(2026, 8, 1), imported_at: Time.zone.local(2026, 8, 11, 9, 0, 0))

      travel_to Time.zone.local(2026, 8, 14, 10, 0, 0) do
        get daily_routine_path(date: "2026-08-14")
        expect(response.body).not_to include(">8月末</h3>")
        expect(response.body).to include("直近の完了")
        expect(response.body).to include("8月末")
        expect(response.body).to include("8/11に8月分の支払いを取り込み")
      end

      travel_to Time.zone.local(2026, 8, 18, 10, 0, 0) do
        get daily_routine_path(date: "2026-08-18")
        expect(response.body).not_to include("直近の完了")
      end
    end

    it "keeps the previous month in history for one week after import" do
      create(:expense, start_month: Date.new(2026, 7, 1), imported_at: Time.zone.local(2026, 8, 11, 9, 0, 0))

      travel_to Time.zone.local(2026, 8, 14, 10, 0, 0) do
        get daily_routine_path(date: "2026-08-14")
        expect(response.body).not_to include(">7月末</h3>")
        expect(response.body).to include("直近の完了")
        expect(response.body).to include("7月末")
        expect(response.body).to include(%(href="#{daily_routine_path(date: "2026-08-11")}"))
      end

      travel_to Time.zone.local(2026, 8, 31, 10, 0, 0) do
        get daily_routine_path(date: "2026-08-31")
        expect(response.body).not_to include("直近の完了")
      end
    end

    it "ignores manually created expenses when judging the month end card" do
      create(:expense, start_month: Date.new(2026, 7, 1), imported_at: nil)

      travel_to Time.zone.local(2026, 8, 11, 10, 0, 0) do
        get daily_routine_path

        expect(response.body).to include(">7月末</h3>")
        expect(response.body).not_to include("✓ 完了")
      end
    end

    it "shows only holiday slot on a weekend" do
      travel_to Time.zone.local(2026, 8, 9, 10, 0, 0) do
        get daily_routine_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(">休日</h3>")
        expect(response.body).not_to include(">平日朝</h3>")
        expect(response.body).not_to include(">平日夜</h3>")
        expect(response.body).not_to include("この日を休みにする")
        expect(response.body).to include("未完了")
      end
    end

    it "shows holiday slot on a weekday marked as off" do
      travel_to Time.zone.local(2026, 8, 11, 10, 0, 0) do
        DailyRoutineOffDay.create!(owner_key: "development", off_on: Date.current)
        get daily_routine_path

        expect(response.body).to include(">休日</h3>")
        expect(response.body).not_to include(">平日朝</h3>")
        expect(response.body).to include("休みを解除")
      end
    end

    it "marks morning complete when today's hypothesis is filled" do
      travel_to Time.zone.local(2026, 8, 11, 10, 0, 0) do
        StockDailyNote.create!(
          owner_key: "development",
          recorded_on: Date.current,
          hypothesis: "朝の仮説"
        )

        get daily_routine_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("完了")
        expect(response.body).to include("完了条件：")
      end
    end

    it "shows completion hints for incomplete weekday slots" do
      travel_to Time.zone.local(2026, 8, 11, 10, 0, 0) do
        get daily_routine_path
        expect(response.body).to include("完了条件：今日の毎日の記録に仮説がある")
        expect(response.body).to include("完了条件：今日の毎日の記録に結果がある")
      end
    end

    it "links the weekday hints to each field of that day even without a note" do
      travel_to Time.zone.local(2026, 8, 14, 10, 0, 0) do
        get daily_routine_path
        expect(response.body).to include(
          %(href="#{CGI.escapeHTML(edit_stock_daily_note_path(date: "2026-08-14", field: "hypothesis"))}")
        )
        expect(response.body).to include(
          %(href="#{CGI.escapeHTML(edit_stock_daily_note_path(date: "2026-08-14", field: "result"))}")
        )
      end
    end

    it "links the weekday hints to the matching field of an existing note" do
      travel_to Time.zone.local(2026, 8, 14, 10, 0, 0) do
        StockDailyNote.create!(
          owner_key: "development",
          recorded_on: Date.current,
          hypothesis: "朝の仮説"
        )

        get daily_routine_path
        expect(response.body).to include(
          %(href="#{stock_daily_note_detail_path(date: "2026-08-14")}")
        )
        expect(response.body).to include(
          %(href="#{CGI.escapeHTML(edit_stock_daily_note_path(date: "2026-08-14", field: "result"))}")
        )
      end
    end

    it "shows the completed holiday card only on the day the entry was created" do
      stock = create_test_stock
      travel_to Time.zone.local(2026, 8, 8, 15, 0, 0) do
        create_test_entry(stock: stock, traded_at: nil)
      end

      travel_to Time.zone.local(2026, 8, 8, 16, 0, 0) do
        get daily_routine_path(date: "2026-08-08")
        expect(response.body).to include(">休日</h3>")
        expect(response.body).to include("✓ 完了")
      end

      travel_to Time.zone.local(2026, 8, 9, 10, 0, 0) do
        get daily_routine_path
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include(">休日</h3>")
      end
    end

    it "shows holiday entry plans in history from completion day through Friday" do
      stock = create_test_stock
      travel_to Time.zone.local(2026, 8, 8, 15, 0, 0) do
        create_test_entry(stock: stock, traded_at: nil)
      end
      %w[2026-08-10 2026-08-11 2026-08-12].each do |d|
        DailyRoutineOffDay.create!(owner_key: "development", off_on: Date.iso8601(d))
      end

      travel_to Time.zone.local(2026, 8, 12, 10, 0, 0) do
        get daily_routine_path(date: "2026-08-12")
        expect(response.body).not_to include(">休日</h3>")
        expect(response.body).to include("直近の完了")
        expect(response.body).to include("エントリー予定（8/8〜8/12）")
        expect(response.body).to include(stock.code)
      end

      travel_to Time.zone.local(2026, 8, 13, 10, 0, 0) do
        get daily_routine_path(date: "2026-08-13")
        expect(response.body).to include("直近の完了")
        expect(response.body).to include(stock.code)
      end

      travel_to Time.zone.local(2026, 8, 17, 10, 0, 0) do
        get daily_routine_path(date: "2026-08-17")
        expect(response.body).not_to include("直近の完了")
      end
    end

    it "shows history when entry was completed on a marked-off weekday" do
      stock = create_test_stock
      %w[2026-08-10 2026-08-11 2026-08-12].each do |d|
        DailyRoutineOffDay.create!(owner_key: "development", off_on: Date.iso8601(d))
      end
      travel_to Time.zone.local(2026, 8, 11, 15, 0, 0) do
        create_test_entry(stock: stock, traded_at: nil)
      end

      travel_to Time.zone.local(2026, 8, 12, 10, 0, 0) do
        get daily_routine_path(date: "2026-08-12")
        expect(response.body).to include("直近の完了")
        expect(response.body).to include("✓ 8/11 完了")
        expect(response.body).to include(stock.code)
      end
    end

    it "shows only the holiday slot on a weekend without entries" do
      travel_to Time.zone.local(2026, 8, 9, 10, 0, 0) do
        get daily_routine_path
        expect(response.body).to include(">休日</h3>")
        expect(response.body).not_to include(">エントリー予定</h")
      end
    end

    it "treats contiguous leave with weekend as one holiday period" do
      stock = create_test_stock
      # Sat 8/8 entry, Mon-Wed leave
      travel_to Time.zone.local(2026, 8, 8, 12, 0, 0) do
        create_test_entry(stock: stock, traded_at: nil)
      end
      %w[2026-08-10 2026-08-11 2026-08-12].each do |d|
        DailyRoutineOffDay.create!(owner_key: "development", off_on: Date.iso8601(d))
      end

      travel_to Time.zone.local(2026, 8, 8, 12, 0, 0) do
        get daily_routine_path(date: "2026-08-08")
        expect(response.body).to include(">休日</h3>")
        expect(response.body).to include("✓ 完了")
        expect(response.body).to include("完了条件：この休み期間（8/8〜8/12）に未約定エントリーがある")
      end

      travel_to Time.zone.local(2026, 8, 12, 10, 0, 0) do
        get daily_routine_path
        expect(response.body).not_to include(">休日</h3>")
      end
    end

    it "shows calendar and accepts a selected date" do
      past = Date.new(2026, 8, 5) # Wednesday
      StockDailyNote.create!(
        owner_key: "development",
        recorded_on: past,
        hypothesis: "過去の仮説",
        result: "過去の結果"
      )

      get daily_routine_path, params: { date: past.iso8601 }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("2026/08/05（水）")
      expect(response.body).to include("2026年8月")
      expect(response.body).to include("完了条件：")
      expect(response.body).to include("今日")
      expect(response.body).to include("一部")
      expect(response.body).to include("未完了")
    end
  end

  describe "off day toggle" do
    it "marks a weekday as off" do
      travel_to Time.zone.local(2026, 8, 11, 10, 0, 0) do
        expect {
          post off_days_daily_routine_path, params: { date: Date.current.iso8601 }
        }.to change(DailyRoutineOffDay, :count).by(1)
        expect(response).to redirect_to(daily_routine_path(date: Date.current.iso8601))
      end
    end

    it "renders the notice as a toast after redirect" do
      travel_to Time.zone.local(2026, 8, 11, 10, 0, 0) do
        post off_days_daily_routine_path, params: { date: Date.current.iso8601 }
        follow_redirect!

        expect(response.body).to include("js-flash-toast")
        expect(response.body).to include("8/11 を休みにしました。")
      end
    end

    it "removes an off day mark" do
      travel_to Time.zone.local(2026, 8, 11, 10, 0, 0) do
        DailyRoutineOffDay.create!(owner_key: "development", off_on: Date.current)
        expect {
          delete off_days_daily_routine_path, params: { date: Date.current.iso8601 }
        }.to change(DailyRoutineOffDay, :count).by(-1)
      end
    end
  end

  describe "GET /daily-routine/settings" do
    it "shows editable items" do
      get daily_routine_settings_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ルーチンの項目を編集")
      expect(response.body).to include("ロイターの新着ニュース確認")
    end
  end

  describe "item CRUD" do
    before { DailyRoutineItem.ensure_defaults_for!("development") }

    it "updates a label" do
      item = DailyRoutineItem.for_owner("development").ordered.first
      patch daily_routine_item_path(item), params: { daily_routine_item: { label: "更新後の項目" } }
      expect(response).to redirect_to(daily_routine_settings_path)
      expect(item.reload.label).to eq("更新後の項目")
    end

    it "creates an item" do
      expect {
        post daily_routine_items_path, params: {
          daily_routine_item: { slot: "weekday_morning", label: "追加項目" }
        }
      }.to change { DailyRoutineItem.for_owner("development").count }.by(1)
      expect(response).to redirect_to(daily_routine_settings_path)
    end

    it "destroys an item" do
      item = DailyRoutineItem.for_owner("development").ordered.first
      expect {
        delete daily_routine_item_path(item)
      }.to change { DailyRoutineItem.for_owner("development").count }.by(-1)
      expect(response).to redirect_to(daily_routine_settings_path)
    end

    it "moves an item down" do
      first, second = DailyRoutineItem.for_owner("development").in_slot("weekday_morning").ordered.limit(2).to_a
      patch move_down_daily_routine_item_path(first)
      expect(response).to redirect_to(daily_routine_settings_path)
      expect(first.reload.position).to be > second.reload.position
    end
  end
end
