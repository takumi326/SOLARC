# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Finance imports", type: :request do
  let!(:minor) { create(:minor_category) }
  let!(:other_minor) { create(:minor_category, major_category: minor.major_category) }
  let!(:amazon_card) { create(:payment_method, name: "Amazonカード", method_type: "card") }
  let!(:paypay_card) { create(:payment_method, name: "PayPayカード", method_type: "card") }

  def build_rows_json(count:, memo_size: 50, minor_id: minor.id, card_id: "smcc_amazon")
    rows = (1..count).map do |i|
      {
        month: "2026-05",
        card_id: card_id,
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
      expect(response.body).to include("これから保存する候補")
      draft = FinanceImportDraft.find_by!(owner_key: "development")
      expect(draft.pending_rows.size).to eq(60)
      expect(draft.phase).to eq("preview")
    end
  end

  describe "recurring expenses in the comparison ledger" do
    it "lists this month's card subscriptions and treats a matching row as duplicate" do
      create(
        :expense,
        minor_category: minor,
        payment_method: amazon_card,
        expense_type: :recurring,
        recurring_cycle: :monthly,
        amount: 3000,
        start_month: Date.new(2026, 4, 1)
      )
      rows = [ { month: "2026-05", card_id: "smcc_amazon", minor_category_id: minor.id, amount: 3000, memo: "Claude Pro" } ]

      post finance_import_path, params: { raw_json: rows.to_json }

      expect(response.body).to include("定期で登録済み")
      expect(response.body).to include("と重複")
      expect(response.body).not_to include('name="line_numbers[]" value="1"')
    end

    it "treats a subscription as duplicate even when the statement shows another card" do
      rakuten = create(:payment_method, name: "楽天カード", method_type: "card")
      create(
        :expense,
        minor_category: minor,
        payment_method: rakuten,
        expense_type: :recurring,
        recurring_cycle: :monthly,
        amount: 1280,
        start_month: Date.new(2026, 4, 1)
      )
      rows = [ { month: "2026-05", card_id: "smcc_amazon", minor_category_id: minor.id, amount: 1280, memo: "YouTube Premium" } ]

      post finance_import_path, params: { raw_json: rows.to_json }

      expect(response.body).to include("と重複")
      expect(response.body).not_to include('name="line_numbers[]" value="1"')
    end

    it "keeps subscriptions paid outside the card out of the ledger" do
      bank = create(:payment_method, name: "みずほ口座引き落とし", method_type: "bank_debit")
      create(
        :expense,
        minor_category: other_minor,
        payment_method: bank,
        expense_type: :recurring,
        recurring_cycle: :monthly,
        amount: 8778,
        start_month: Date.new(2026, 4, 1)
      )

      post finance_import_path, params: { raw_json: build_rows_json(count: 1) }

      expect(response.body).not_to include("みずほ口座引き落とし")
    end

    it "skips a yearly subscription outside its renewal month" do
      create(
        :expense,
        minor_category: minor,
        payment_method: amazon_card,
        expense_type: :recurring,
        recurring_cycle: :yearly,
        renewal_month: 11,
        amount: 5900,
        start_month: Date.new(2026, 4, 1)
      )

      post finance_import_path, params: { raw_json: build_rows_json(count: 1) }

      expect(response.body).not_to include("定期で登録済み")
    end
  end

  describe "candidate row order" do
    it "numbers the candidate rows by category order instead of the JSON order" do
      food = create(:minor_category, name: "食費", major_category: minor.major_category)
      rows = [
        { month: "2026-05", card_id: "smcc_amazon", minor_category_id: food.id, amount: 1000, memo: "a" },
        { month: "2026-05", card_id: "smcc_amazon", minor_category_id: minor.id, amount: 1100, memo: "b" },
        { month: "2026-05", card_id: "smcc_amazon", minor_category_id: food.id, amount: 300, memo: "c" }
      ]
      post finance_import_path, params: { raw_json: rows.to_json }

      candidates = response.body[/これから保存する候補.*?<\/table>/m]
      numbered_memos = candidates.scan(/rows\[(\d+)\]\[memo\]" value="(\w+)"/)
      expect(numbered_memos).to eq([ [ "1", "b" ], [ "2", "c" ], [ "3", "a" ] ])
    end
  end

  describe "payment method selection after JSON import" do
    it "shows one payment method select per card_id on preview" do
      rows = [
        { month: "2026-05", card_id: "smcc_amazon", minor_category_id: minor.id, amount: 1000, memo: "a" },
        { month: "2026-05", card_id: "smcc_amazon", minor_category_id: minor.id, amount: 1100, memo: "b" },
        { month: "2026-05", card_id: "paypay_jcb", minor_category_id: minor.id, amount: 2000, memo: "c" }
      ]
      post finance_import_path, params: { raw_json: rows.to_json }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("import-card-summary")
      expect(response.body).to include('name="card_payment_methods[smcc_amazon]"')
      expect(response.body).to include('name="card_payment_methods[paypay_jcb]"')
      expect(response.body).to include("data-import-card-payment-method")
      expect(response.body).to include("data-import-payment-label")
      expect(response.body).to include("finance_import_preview")
      expect(response.body).to include("import-final-preview-by-card")
      expect(response.body).to include(">Amazonカード<")
      expect(response.body).to include(">PayPayカード<")
      expect(response.body.scan('name="card_payment_methods[').size).to eq(2)
    end

    it "preselects the matching payment method when card_id resolves" do
      post finance_import_path, params: { raw_json: build_rows_json(count: 1, memo_size: 3, card_id: "paypay_jcb") }

      expect(response).to have_http_status(:ok)
      draft = FinanceImportDraft.find_by!(owner_key: "development")
      expect(draft.pending_rows.first["payment_method_id"]).to eq(paypay_card.id)
      expect(response.body).to match(/name="card_payment_methods\[paypay_jcb\]"[\s\S]*?option value="#{paypay_card.id}"[^>]*selected/)
    end

    it "still opens preview when card_id does not match any payment method" do
      rows = [ { month: "2026-05", card_id: "mystery", minor_category_id: minor.id, amount: 1000, memo: "x" } ]
      post finance_import_path, params: { raw_json: rows.to_json }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("これから保存する候補")
      expect(response.body).to include('name="card_payment_methods[mystery]"')
      draft = FinanceImportDraft.find_by!(owner_key: "development")
      expect(draft.pending_rows.first["payment_method_id"]).to be_nil
      expect(response.body).to match(/option value=""[^>]*>選択してください/)
    end

    it "still opens preview when known card_id has no payment method master" do
      PaymentMethod.delete_all
      rows = [ { month: "2026-05", card_id: "smcc_amazon", minor_category_id: minor.id, amount: 1000, memo: "x" } ]
      post finance_import_path, params: { raw_json: rows.to_json }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("これから保存する候補")
      draft = FinanceImportDraft.find_by!(owner_key: "development")
      expect(draft.pending_rows.first["payment_method_id"]).to be_nil
    end

    it "applies one chosen payment method to all rows with the same card_id" do
      rows = [
        { month: "2026-05", card_id: "smcc_amazon", minor_category_id: minor.id, amount: 1500, memo: "a" },
        { month: "2026-05", card_id: "smcc_amazon", minor_category_id: minor.id, amount: 1600, memo: "b" }
      ]
      post finance_import_path, params: { raw_json: rows.to_json }
      draft = FinanceImportDraft.find_by!(owner_key: "development")
      lines = draft.pending_rows.map { |row| row["line_number"] }

      post commit_finance_import_path, params: {
        line_numbers: lines,
        compare_month: "2026-05",
        card_payment_methods: { "smcc_amazon" => paypay_card.id }
      }

      expect(response).to redirect_to(finance_summary_path)
      expect(Expense.order(:id).last(2).map(&:payment_method)).to all(eq(paypay_card))
    end

    it "rejects commit when payment method is not selected for a card_id" do
      rows = [ { month: "2026-05", card_id: "mystery", minor_category_id: minor.id, amount: 1000, memo: "x" } ]
      post finance_import_path, params: { raw_json: rows.to_json }
      draft = FinanceImportDraft.find_by!(owner_key: "development")
      line = draft.pending_rows.first["line_number"]

      post commit_finance_import_path, params: {
        line_numbers: [ line ],
        compare_month: "2026-05",
        card_payment_methods: { "mystery" => "" }
      }

      expect(response).to redirect_to(finance_import_path)
      expect(flash[:alert]).to include("card_id「mystery」の支払方法を選んでください")
      expect(Expense.count).to eq(0)
    end

    it "imports after choosing payment method for an unknown card_id" do
      rows = [ { month: "2026-05", card_id: "mystery", minor_category_id: minor.id, amount: 1500, memo: "manual" } ]
      post finance_import_path, params: { raw_json: rows.to_json }
      draft = FinanceImportDraft.find_by!(owner_key: "development")
      line = draft.pending_rows.first["line_number"]

      post commit_finance_import_path, params: {
        line_numbers: [ line ],
        compare_month: "2026-05",
        card_payment_methods: { "mystery" => paypay_card.id }
      }

      expect(response).to redirect_to(finance_summary_path)
      expect(Expense.order(:id).last.payment_method).to eq(paypay_card)
    end
  end

  describe "POST /finance/import/commit" do
    it "imports rows with edited category and memo" do
      post finance_import_path, params: { raw_json: build_rows_json(count: 1, memo_size: 5) }
      draft = FinanceImportDraft.find_by!(owner_key: "development")

      post commit_finance_import_path, params: {
        line_numbers: [ draft.pending_rows.first["line_number"] ],
        compare_month: "2026-05",
        card_payment_methods: { "smcc_amazon" => amazon_card.id },
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
      expect(expense.payment_method).to eq(amazon_card)
      expect(FinanceImportDraft.find_by(owner_key: "development")).to be_nil
    end

    it "imports multiple card types in one commit" do
      rows = [
        { month: "2026-05", card_id: "smcc_amazon", minor_category_id: minor.id, amount: 1000, memo: "a" },
        { month: "2026-05", card_id: "paypay_jcb", minor_category_id: minor.id, amount: 2000, memo: "b" }
      ]
      post finance_import_path, params: { raw_json: rows.to_json }
      draft = FinanceImportDraft.find_by!(owner_key: "development")

      post commit_finance_import_path, params: {
        line_numbers: draft.pending_rows.map { |row| row["line_number"] },
        compare_month: "2026-05"
      }

      expect(response).to redirect_to(finance_summary_path)
      expenses = Expense.order(:id).last(2)
      expect(expenses.map(&:payment_method)).to contain_exactly(amazon_card, paypay_card)
    end

    it "appends gap-check rows into the preview draft" do
      post finance_import_path, params: { raw_json: build_rows_json(count: 1, memo_size: 3) }
      draft = FinanceImportDraft.find_by!(owner_key: "development")
      expect(draft.pending_rows.size).to eq(1)

      extra = [ { month: "2026-05", card_id: "paypay_jcb", minor_category_id: minor.id, amount: 3300, memo: "[不足追加] x" } ].to_json
      post append_finance_import_path, params: { raw_json: extra }

      expect(response).to redirect_to(finance_import_path)
      draft.reload
      expect(draft.pending_rows.size).to eq(2)
      expect(draft.pending_rows.last["memo"]).to include("不足追加")
    end
  end

  describe "GET /finance/import" do
    it "shows import form" do
      get finance_import_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("実績を取込")
    end

    it "links to each card statement page" do
      get finance_import_path

      expect(response.body).to include("https://www.smbc-card.com/memx/web_meisai/top/index.html")
      expect(response.body).to include("https://www.paypay-card.co.jp/member/statement/top")
    end

    it "shows import form when finance_import_drafts table is missing" do
      allow(FinanceImportDraft).to receive(:storage_available?).and_return(false)

      get finance_import_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("実績を取込")
    end
  end
end
