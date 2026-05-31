require "rails_helper"

RSpec.describe "Api::Expenses", type: :request do
  let(:headers) { { "HOST" => "www.example.com" } }
  let!(:major) { create(:major_category, kind: :expense) }
  let!(:minor) { create(:minor_category, major_category: major) }
  let!(:payment_method) { create(:payment_method, method_type: "card") }

  describe "GET /api/expenses" do
    it "returns expenses list" do
      create(:expense, minor_category: minor, payment_method: payment_method)

      get "/api/expenses", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"].size).to eq(1)
      expect(body["data"].first["minor_category_id"]).to eq(minor.id)
    end
  end

  describe "POST /api/expenses" do
    it "creates an expense" do
      expect {
        post "/api/expenses",
             params: {
               expense: {
                 minor_category_id: minor.id,
                 payment_method_id: payment_method.id,
                 expense_type: "recurring",
                 recurring_cycle: "monthly",
                 renewal_month: nil,
                 amount: 12000,
                 start_month: "2026-05-01",
                 end_month: nil
               }
             },
             headers: headers
      }.to change(Expense, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["data"]["expense_type"]).to eq("recurring")
      expect(body["data"]["recurring_cycle"]).to eq("monthly")
      expect(body["data"]["amount"]).to eq(12000)
      expect(body["data"]["memo"]).to be_nil
    end

    it "creates an expense with memo" do
      post "/api/expenses",
           params: {
             expense: {
               minor_category_id: minor.id,
               payment_method_id: payment_method.id,
               expense_type: "one_time",
               recurring_cycle: "monthly",
               renewal_month: nil,
               amount: 500,
               start_month: "2026-05-01",
               end_month: "2026-05-01",
               memo: "  外食メモ  "
             }
           },
           headers: headers

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["data"]["memo"]).to eq("外食メモ")
    end

    it "returns 422 for invalid params" do
      post "/api/expenses",
           params: { expense: { minor_category_id: minor.id, payment_method_id: payment_method.id } },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /api/expenses/:id" do
    let!(:expense) { create(:expense, minor_category: minor, payment_method: payment_method) }

    it "updates an expense" do
      patch "/api/expenses/#{expense.id}",
            params: { expense: { expense_type: "recurring" } },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(expense.reload.expense_type).to eq("recurring")
    end

    it "updates memo" do
      patch "/api/expenses/#{expense.id}",
            params: { expense: { memo: "備考" } },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(expense.reload.memo).to eq("備考")
    end

    it "returns 404 for missing expense" do
      patch "/api/expenses/0",
            params: { expense: { expense_type: "recurring" } },
            headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/expenses/:id" do
    let!(:expense) { create(:expense, minor_category: minor, payment_method: payment_method) }

    it "destroys an expense" do
      expect {
        delete "/api/expenses/#{expense.id}", headers: headers
      }.to change(Expense, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "destroys linked ledger transactions when destroying expense" do
      expense = create(:expense, minor_category: minor, payment_method: payment_method)
      tx = Transaction.create!(month: Date.new(2026, 6, 1), amount: -12_000)
      ExpenseTransaction.create!(expense: expense, ledger_transaction: tx)

      expect {
        delete "/api/expenses/#{expense.id}", headers: headers
      }.to change(Expense, :count).by(-1).and change(Transaction, :count).by(-1)

      expect(response).to have_http_status(:no_content)
      expect(Transaction.find_by(id: tx.id)).to be_nil
    end
  end

  describe "GET /api/expenses/:id/actuals" do
    it "returns actual transaction list for expense" do
      expense = create(:expense, minor_category: minor, payment_method: payment_method)
      tx = Transaction.create!(month: Date.new(2026, 6, 1), amount: -12_000)
      ExpenseTransaction.create!(expense: expense, ledger_transaction: tx)

      get "/api/expenses/#{expense.id}/actuals", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"].size).to eq(1)
      expect(body["data"].first["month"]).to eq("2026-06-01")
      expect(body["data"].first["amount"]).to eq("12000.0")
    end

    it "deletes one ledger row via DELETE /api/expenses/:id/actuals/:transaction_id" do
      expense = create(:expense, minor_category: minor, payment_method: payment_method)
      june = Date.new(2026, 6, 1)
      tx_keep = Transaction.create!(month: june, amount: -800)
      tx_drop = Transaction.create!(month: june, amount: -800)
      ExpenseTransaction.create!(expense: expense, ledger_transaction: tx_keep)
      ExpenseTransaction.create!(expense: expense, ledger_transaction: tx_drop)

      delete "/api/expenses/#{expense.id}/actuals/#{tx_drop.id}", headers: headers
      expect(response).to have_http_status(:no_content)

      get "/api/expenses/#{expense.id}/actuals", headers: headers
      body = JSON.parse(response.body)
      expect(body["data"].size).to eq(1)
      expect(body["data"].first["transaction_id"]).to eq(tx_keep.id)
    end

    it "returns 404 when transaction_id is not linked to the expense" do
      expense = create(:expense, minor_category: minor, payment_method: payment_method)
      other = create(:expense, minor_category: minor, payment_method: payment_method)
      tx = Transaction.create!(month: Date.new(2026, 6, 1), amount: -1)
      ExpenseTransaction.create!(expense: other, ledger_transaction: tx)

      delete "/api/expenses/#{expense.id}/actuals/#{tx.id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "updates actual month and amount via PATCH" do
      expense = create(:expense, minor_category: minor, payment_method: payment_method)
      tx = Transaction.create!(month: Date.new(2026, 6, 1), amount: -800)
      ExpenseTransaction.create!(expense: expense, ledger_transaction: tx)

      patch "/api/expenses/#{expense.id}/actuals/#{tx.id}",
            params: { actual: { month: "2026-07-01", amount: 900 } },
            headers: headers

      expect(response).to have_http_status(:ok)
      tx.reload
      expect(tx.month).to eq(Date.new(2026, 7, 1))
      expect(tx.amount).to eq(-900)
      body = JSON.parse(response.body)
      expect(body.dig("data", "transaction_id")).to eq(tx.id)
      expect(body.dig("data", "amount").to_f).to eq(900.0)
    end

    it "returns 422 when update would duplicate another row's month" do
      expense = create(:expense, minor_category: minor, payment_method: payment_method)
      june = Date.new(2026, 6, 1)
      july = Date.new(2026, 7, 1)
      tx_a = Transaction.create!(month: june, amount: -100)
      tx_b = Transaction.create!(month: july, amount: -200)
      ExpenseTransaction.create!(expense: expense, ledger_transaction: tx_a)
      ExpenseTransaction.create!(expense: expense, ledger_transaction: tx_b)

      patch "/api/expenses/#{expense.id}/actuals/#{tx_b.id}",
            params: { actual: { month: "2026-06-01", amount: 200 } },
            headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "bulk-updates actual amounts from month for recurring expense" do
      expense = create(
        :expense,
        minor_category: minor,
        payment_method: payment_method,
        expense_type: :recurring,
        recurring_cycle: :monthly,
        amount: 10_000,
        start_month: Date.new(2026, 1, 1)
      )
      jan = Transaction.create!(month: Date.new(2026, 1, 1), amount: -10_000)
      may = Transaction.create!(month: Date.new(2026, 5, 1), amount: -10_000)
      dec = Transaction.create!(month: Date.new(2026, 12, 1), amount: -10_000)
      ExpenseTransaction.create!(expense: expense, ledger_transaction: jan)
      ExpenseTransaction.create!(expense: expense, ledger_transaction: may)
      ExpenseTransaction.create!(expense: expense, ledger_transaction: dec)

      post "/api/expenses/#{expense.id}/actuals/bulk_from_month",
           params: { bulk: { from_month: "2026-05-01", amount: 15_000 } },
           headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "updated_count")).to eq(2)
      expect(jan.reload.amount).to eq(-10_000)
      expect(may.reload.amount).to eq(-15_000)
      expect(dec.reload.amount).to eq(-15_000)
      expect(expense.reload.amount).to eq(15_000)
    end

    it "rejects bulk update for one-time expense" do
      expense = create(:expense, minor_category: minor, payment_method: payment_method, expense_type: :one_time)

      post "/api/expenses/#{expense.id}/actuals/bulk_from_month",
           params: { bulk: { from_month: "2026-05-01", amount: 1000 } },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
