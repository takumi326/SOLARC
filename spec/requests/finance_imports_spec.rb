# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Finance imports", type: :request do
  let!(:minor) { create(:minor_category) }
  let!(:other_minor) { create(:minor_category, major_category: minor.major_category) }
  let!(:amazon_card) { create(:payment_method, name: "Amazonカード", method_type: "card") }

  def build_rows_json(count:, memo_size: 50, minor_id: minor.id)
    rows = (1..count).map do |i|
      {
        month: "2026-05",
        minor_category_id: minor_id,
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

  describe "POST /finance/import/commit" do
    it "imports rows with edited category and memo" do
      post finance_import_path, params: { raw_json: build_rows_json(count: 1, memo_size: 5) }
      draft = FinanceImportDraft.find_by!(owner_key: "development")

      post commit_finance_import_path, params: {
        line_numbers: [ draft.pending_rows.first["line_number"] ],
        compare_month: "2026-05",
        rows: {
          draft.pending_rows.first["line_number"].to_s => {
            minor_category_id: other_minor.id,
            memo: "編集後メモ"
          }
        }
      }

      expense = Expense.order(:id).last
      expect(response).to redirect_to(finance_summary_path)
      expect(expense.minor_category_id).to eq(other_minor.id)
      expect(expense.memo).to eq("編集後メモ")
      expect(FinanceImportDraft.find_by(owner_key: "development")).to be_nil
    end
  end

  describe "GET /finance/import" do
    it "shows import form" do
      get finance_import_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("実績を取込")
    end

    it "shows import form when finance_import_drafts table is missing" do
      allow(FinanceImportDraft).to receive(:storage_available?).and_return(false)

      get finance_import_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("実績を取込")
    end
  end
end
