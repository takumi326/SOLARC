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
        expect(DailyRoutineItem.for_owner("development").count).to eq(18)
      end
    end

    it "shows only holiday slot on a weekend" do
      travel_to Time.zone.local(2026, 8, 9, 10, 0, 0) do
        get daily_routine_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(">休日</h3>")
        expect(response.body).not_to include(">平日朝</h3>")
        expect(response.body).not_to include(">平日夜</h3>")
        expect(response.body).to include("土日は休み")
        expect(response.body).to include("休みの日用")
        expect(response.body).to include("休日・未完了")
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

    it "marks holiday complete on Sunday when entry was created on Saturday" do
      stock = create_test_stock
      travel_to Time.zone.local(2026, 8, 8, 15, 0, 0) do
        create_test_entry(stock: stock, traded_at: nil)
      end

      travel_to Time.zone.local(2026, 8, 9, 10, 0, 0) do
        get daily_routine_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("✓ 完了")
        expect(response.body).to include("完了条件：この休み期間（8/8〜8/9）に未約定エントリーがある")
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

      travel_to Time.zone.local(2026, 8, 12, 10, 0, 0) do
        get daily_routine_path
        expect(response.body).to include(">休日</h3>")
        expect(response.body).to include("✓ 完了")
        expect(response.body).not_to include("期間内のどちらかで達成すればOK")
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
      expect(response.body).to include("日付を選ぶ")
      expect(response.body).to include("2026年8月")
      expect(response.body).to include("完了条件：")
      expect(response.body).to include("今日")
      expect(response.body).to include("すべて完了")
      expect(response.body).to include("平日・未完了")
      expect(response.body).to include("休み・未完了")
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
