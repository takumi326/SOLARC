# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Finance imports", type: :request do
  let!(:minor) { create(:minor_category) }

  def build_rows_json(count:, memo_size: 50)
    rows = (1..count).map do |i|
      {
        month: "2026-05",
        minor_category_id: minor.id,
        amount: 1000 + i,
        memo: "item-#{i}-#{'x' * memo_size}"
      }
    end
    rows.to_json
  end

  describe "POST /finance/import" do
    it "stores large preview data in the database instead of the session cookie" do
      post finance_import_path, params: { raw_json: build_rows_json(count: 60, memo_size: 80) }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今回取り込む")
      draft = FinanceImportDraft.find_by!(owner_key: "development")
      expect(draft.pending_rows.size).to eq(60)
      expect(draft.phase).to eq("preview")
    end
  end

  describe "GET /finance/import" do
    it "shows import form" do
      get finance_import_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("実績を取込")
    end
  end
end
