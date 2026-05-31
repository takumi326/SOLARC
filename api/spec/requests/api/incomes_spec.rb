require "rails_helper"

RSpec.describe "Api::Incomes", type: :request do
  let(:headers) { { "HOST" => "www.example.com" } }
  let!(:major) { create(:major_category, kind: :income) }
  let!(:minor) { create(:minor_category, major_category: major) }

  describe "GET /api/incomes" do
    it "returns incomes list" do
      create(:income, minor_category: minor)

      get "/api/incomes", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"].size).to eq(1)
      expect(body["data"].first["minor_category_id"]).to eq(minor.id)
    end
  end

  describe "POST /api/incomes" do
    it "creates an income" do
      expect {
        post "/api/incomes",
             params: {
               income: {
                 minor_category_id: minor.id,
                 income_type: "recurring",
                 amount: 320000,
                 start_month: "2026-05-01",
                 end_month: nil
               }
             },
             headers: headers
      }.to change(Income, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["data"]["income_type"]).to eq("recurring")
      expect(body["data"]["amount"]).to eq(320000)
    end

    it "returns 422 for invalid params" do
      post "/api/incomes",
           params: { income: { minor_category_id: minor.id } },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /api/incomes/:id" do
    let!(:income) { create(:income, minor_category: minor) }

    it "updates an income" do
      patch "/api/incomes/#{income.id}",
            params: { income: { income_type: "recurring" } },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(income.reload.income_type).to eq("recurring")
    end

    it "returns 404 for missing income" do
      patch "/api/incomes/0",
            params: { income: { income_type: "recurring" } },
            headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/incomes/:id" do
    let!(:income) { create(:income, minor_category: minor) }

    it "destroys an income" do
      expect {
        delete "/api/incomes/#{income.id}", headers: headers
      }.to change(Income, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "destroys linked ledger transactions when destroying income" do
      income = create(:income, minor_category: minor)
      tx = Transaction.create!(month: Date.new(2026, 6, 1), amount: 320_000)
      IncomeTransaction.create!(income: income, ledger_transaction: tx)

      expect {
        delete "/api/incomes/#{income.id}", headers: headers
      }.to change(Income, :count).by(-1).and change(Transaction, :count).by(-1)

      expect(response).to have_http_status(:no_content)
      expect(Transaction.find_by(id: tx.id)).to be_nil
    end
  end

  describe "GET /api/incomes/:id/actuals" do
    it "returns actual transaction list for income" do
      income = create(:income, minor_category: minor)
      tx = Transaction.create!(month: Date.new(2026, 6, 1), amount: 320_000)
      IncomeTransaction.create!(income: income, ledger_transaction: tx)

      get "/api/incomes/#{income.id}/actuals", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"].size).to eq(1)
      expect(body["data"].first["month"]).to eq("2026-06-01")
      expect(body["data"].first["amount"]).to eq(320000.0)
    end

    it "deletes one ledger row via DELETE /api/incomes/:id/actuals/:transaction_id" do
      income = create(:income, minor_category: minor)
      june = Date.new(2026, 6, 1)
      tx_keep = Transaction.create!(month: june, amount: 1000)
      tx_drop = Transaction.create!(month: june, amount: 1000)
      IncomeTransaction.create!(income: income, ledger_transaction: tx_keep)
      IncomeTransaction.create!(income: income, ledger_transaction: tx_drop)

      delete "/api/incomes/#{income.id}/actuals/#{tx_drop.id}", headers: headers
      expect(response).to have_http_status(:no_content)

      get "/api/incomes/#{income.id}/actuals", headers: headers
      body = JSON.parse(response.body)
      expect(body["data"].size).to eq(1)
      expect(body["data"].first["transaction_id"]).to eq(tx_keep.id)
    end

    it "updates actual month and amount via PATCH" do
      income = create(:income, minor_category: minor)
      tx = Transaction.create!(month: Date.new(2026, 6, 1), amount: 320_000)
      IncomeTransaction.create!(income: income, ledger_transaction: tx)

      patch "/api/incomes/#{income.id}/actuals/#{tx.id}",
            params: { actual: { month: "2026-08-01", amount: 400_000 } },
            headers: headers

      expect(response).to have_http_status(:ok)
      tx.reload
      expect(tx.month).to eq(Date.new(2026, 8, 1))
      expect(tx.amount).to eq(400_000)
    end

    it "bulk-updates actual amounts from month for recurring income" do
      income = create(
        :income,
        minor_category: minor,
        income_type: :recurring,
        amount: 300_000,
        start_month: Date.new(2026, 1, 1)
      )
      jan = Transaction.create!(month: Date.new(2026, 1, 1), amount: 300_000)
      jun = Transaction.create!(month: Date.new(2026, 6, 1), amount: 300_000)
      IncomeTransaction.create!(income: income, ledger_transaction: jan)
      IncomeTransaction.create!(income: income, ledger_transaction: jun)

      post "/api/incomes/#{income.id}/actuals/bulk_from_month",
           params: { bulk: { from_month: "2026-06-01", amount: 350_000 } },
           headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "updated_count")).to eq(1)
      expect(jan.reload.amount).to eq(300_000)
      expect(jun.reload.amount).to eq(350_000)
      expect(income.reload.amount).to eq(350_000)
    end
  end
end
