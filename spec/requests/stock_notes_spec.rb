require "rails_helper"

RSpec.describe "StockNotes", type: :request do
  let(:stock) { create_test_stock }

  describe "POST /stocks/:stock_id/stock_notes" do
    it "creates note" do
      post stock_stock_notes_path(stock), params: {
        stock_note: { noted_on: Date.current.iso8601, title: "タイトル", note: "本文" }
      }
      expect(response).to redirect_to(stock_path(stock))
      expect(stock.stock_notes.count).to eq(1)
    end
  end

  describe "PATCH /stocks/:stock_id/stock_notes/:id" do
    it "updates note" do
      note = stock.stock_notes.create!(noted_on: Date.current, title: "旧", note: "旧本文")
      patch stock_stock_note_path(stock, note), params: {
        stock_note: { noted_on: Date.current.iso8601, title: "新", note: "新本文" }
      }
      expect(response).to redirect_to(stock_path(stock))
      expect(note.reload.title).to eq("新")
    end
  end

  describe "DELETE /stocks/:stock_id/stock_notes/:id" do
    it "destroys note" do
      note = stock.stock_notes.create!(noted_on: Date.current, title: "t", note: "n")
      delete stock_stock_note_path(stock, note)
      expect(response).to redirect_to(stock_path(stock))
      expect(StockNote.exists?(note.id)).to be(false)
    end
  end
end
