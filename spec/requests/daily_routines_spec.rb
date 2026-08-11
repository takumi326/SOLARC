# frozen_string_literal: true

require "rails_helper"

RSpec.describe "DailyRoutines", type: :request do
  describe "GET /daily-routine" do
    it "shows dashboard with seeded items and incomplete slots" do
      get daily_routine_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ルーチン")
      expect(response.body).to include("平日朝")
      expect(response.body).to include("平日夜")
      expect(response.body).to include("休日")
      expect(response.body).to include("グリーンさんの Discord 確認")
      expect(response.body).to include("未完了")
      expect(response.body).to include("1.")
      expect(response.body).not_to include("今日の対象枠")
      expect(DailyRoutineItem.for_owner("development").count).to eq(18)
    end

    it "marks morning complete when today's hypothesis is filled" do
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

    it "shows completion hints for incomplete slots" do
      get daily_routine_path
      expect(response.body).to include("完了条件：今日の毎日の記録に仮説がある")
      expect(response.body).to include("完了条件：今日の毎日の記録に結果がある")
      expect(response.body).to include("完了条件：今日につくった未約定エントリーがある")
    end

    it "marks holiday complete when an unsettled entry exists today" do
      stock = create_test_stock
      create_test_entry(stock: stock, traded_at: nil)

      get daily_routine_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("完了")
    end

    it "shows calendar and accepts a selected date" do
      past = Date.current - 3
      StockDailyNote.create!(
        owner_key: "development",
        recorded_on: past,
        hypothesis: "過去の仮説",
        result: "過去の結果"
      )

      get daily_routine_path, params: { date: past.iso8601 }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("日付を選ぶ")
      expect(response.body).to include(past.strftime("%Y年%-m月"))
      expect(response.body).to include("完了条件：")
      expect(response.body).to include("今日へ戻る")
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
