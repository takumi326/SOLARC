require "rails_helper"

RSpec.describe "StockDailyNotes", type: :request do
  describe "GET /stocks/daily" do
    it "shows daily notes list" do
      StockDailyNote.create!(
        owner_key: "development",
        recorded_on: Date.current,
        hypothesis: "仮説テスト",
        result: "結果テスト",
        sector_research: "セクターテスト"
      )

      get stock_daily_notes_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("毎日の記録")
      expect(response.body).to include("保存済み記録")
      expect(response.body).to include("プロンプトコピー")
    end

    it "marks empty result as × like the routine evening check" do
      StockDailyNote.create!(
        owner_key: "development",
        recorded_on: Date.new(2026, 8, 17),
        hypothesis: "朝の仮説",
        result: "",
        sector_research: ""
      )

      get stock_daily_notes_path
      expect(response.body).to include('title="仮説あり"')
      expect(response.body).to include('title="結果なし"')
      expect(response.body).to include('title="セクター調べなし"')
      expect(response.body).not_to include('title="結果あり"')
    end
  end

  describe "GET /stocks/daily/detail" do
    it "shows note detail" do
      note = StockDailyNote.create!(
        owner_key: "development",
        recorded_on: Date.current,
        hypothesis: "## 仮説",
        result: "",
        sector_research: ""
      )

      get stock_daily_note_detail_path(date: note.recorded_on.iso8601)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("仮説")
    end
  end

  describe "GET /stocks/daily/prompts" do
    it "shows prompt edit form" do
      get edit_stock_daily_prompts_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("毎日の記録プロンプト")
    end
  end

  describe "PATCH /stocks/daily/prompts" do
    it "saves prompts" do
      patch stock_daily_prompts_path, params: {
        stock_daily_prompts: {
          hypothesis: "H {{date}}",
          result: "R {{result}}",
          sector: "S"
        }
      }
      expect(response).to redirect_to(stock_daily_notes_path)
      row = UserPreference.find_by(owner_key: "development")
      expect(row.stock_daily_hypothesis_prompt).to eq("H {{date}}")
    end
  end

  describe "GET /stock_daily_notes/new" do
    it "defaults recorded_on to Tokyo calendar date near UTC midnight" do
      travel_to Time.utc(2026, 8, 10, 15, 0, 0) do
        # 2026-08-10 15:00 UTC = 2026-08-11 00:00 JST
        get new_stock_daily_note_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('value="2026-08-11"')
      end
    end
  end

  describe "POST /stock_daily_notes" do
    it "creates note and redirects to daily notes list" do
      post stock_daily_notes_create_path,
           params: {
             stock_daily_note: { recorded_on: Date.current.iso8601, hypothesis: "new hypothesis" }
           }

      expect(response).to redirect_to(stock_daily_notes_path)
      note = StockDailyNote.find_by!(owner_key: "development", recorded_on: Date.current)
      expect(note.hypothesis).to eq("new hypothesis")
    end
  end

  describe "PATCH /stock_daily_notes" do
    it "updates field and redirects to daily notes list" do
      note = StockDailyNote.create!(
        owner_key: "development",
        recorded_on: Date.current,
        hypothesis: "old"
      )

      patch stock_daily_note_path,
            params: {
              field: "hypothesis",
              stock_daily_note: { recorded_on: note.recorded_on.iso8601, body: "new" }
            }

      expect(response).to redirect_to(stock_daily_notes_path)
      expect(note.reload.hypothesis).to eq("new")
    end
  end

  describe "GET /stock_daily_notes/edit" do
    it "opens the result form for a day that has no note yet" do
      get edit_stock_daily_note_path(date: "2026-08-14", field: "result")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("結果")
    end

    it "pre-fills the morning hypothesis template when empty" do
      get edit_stock_daily_note_path(date: "2026-08-14", field: "hypothesis")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("## 米国市場")
      expect(response.body).to include("## 国内市況")
      expect(response.body).to include("## ニュース")
      expect(response.body).to include("## 個別材料")
    end

    it "keeps an existing hypothesis instead of the template" do
      StockDailyNote.create!(
        owner_key: "development",
        recorded_on: Date.new(2026, 8, 14),
        hypothesis: "既存の仮説"
      )

      get edit_stock_daily_note_path(date: "2026-08-14", field: "hypothesis")
      expect(response.body).to include("既存の仮説")
      expect(response.body).not_to include("## 米国市場")
    end

    it "pre-fills the evening result template when empty" do
      get edit_stock_daily_note_path(date: "2026-08-14", field: "result")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("## 所有株")
      expect(response.body).to include("## 日経平均、TOPIX")
      expect(response.body).to include("## セクター")
    end

    it "keeps an existing result instead of the template" do
      StockDailyNote.create!(
        owner_key: "development",
        recorded_on: Date.new(2026, 8, 14),
        result: "既存の結果"
      )

      get edit_stock_daily_note_path(date: "2026-08-14", field: "result")
      expect(response.body).to include("既存の結果")
      expect(response.body).not_to include("## 所有株")
    end
  end

  describe "PATCH /stock_daily_notes without an existing note" do
    it "creates the note with only the result filled in" do
      patch stock_daily_note_path,
            params: {
              field: "result",
              stock_daily_note: { recorded_on: "2026-08-14", body: "結果だけ書く" }
            }

      expect(response).to redirect_to(stock_daily_notes_path)
      note = StockDailyNote.find_by!(owner_key: "development", recorded_on: Date.new(2026, 8, 14))
      expect(note.result).to eq("結果だけ書く")
      expect(note.hypothesis).to be_blank
    end
  end

  describe "DELETE /stock_daily_notes/:id" do
    it "destroys note" do
      note = StockDailyNote.create!(
        owner_key: "development",
        recorded_on: Date.current,
        hypothesis: "x"
      )
      delete destroy_stock_daily_note_path(note)
      expect(response).to redirect_to(stock_daily_notes_path)
      expect(StockDailyNote.exists?(note.id)).to be(false)
    end
  end
end
