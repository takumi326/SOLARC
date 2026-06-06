require "rails_helper"

RSpec.describe "Api::UserPreferences", type: :request do
  let(:headers) { { "HOST" => "www.example.com" } }

  describe "GET /api/user_preferences" do
    it "returns nil template when no row exists" do
      get "/api/user_preferences", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["import_claude_prompt_template"]).to be_nil
      expect(body["data"]["stock_daily_hypothesis_prompt"]).to be_nil
      expect(body["data"]["stock_daily_result_prompt"]).to be_nil
      expect(body["data"]["stock_daily_sector_prompt"]).to be_nil
    end
  end

  describe "PATCH /api/user_preferences stock_daily_*_prompt" do
    it "persists without changing import template" do
      UserPreference.create!(
        owner_key: "development",
        import_claude_prompt_template: "x {{CATALOG}} {{PAYMENT_METHOD_NAME}} {{EXAMPLE_MINOR_ID}}",
        stock_daily_hypothesis_prompt: nil,
        stock_daily_result_prompt: nil,
        stock_daily_sector_prompt: nil
      )

      hypothesis = "## 朝\n仮説用"
      result = "結果用プロンプト"
      sector = "セクター用"

      patch "/api/user_preferences",
            params: {
              user_preference: {
                stock_daily_hypothesis_prompt: hypothesis,
                stock_daily_result_prompt: result,
                stock_daily_sector_prompt: sector
              }
            },
            headers: headers

      expect(response).to have_http_status(:ok)
      row = UserPreference.find_by(owner_key: "development")
      expect(row.stock_daily_hypothesis_prompt).to eq(hypothesis)
      expect(row.stock_daily_result_prompt).to eq(result)
      expect(row.stock_daily_sector_prompt).to eq(sector)
      expect(row.import_claude_prompt_template).to include("{{CATALOG}}")
    end
  end

  describe "PATCH /api/user_preferences" do
    it "persists and returns the template" do
      template = "x {{CATALOG}} {{PAYMENT_METHOD_NAME}} {{EXAMPLE_MINOR_ID}}"

      patch "/api/user_preferences",
            params: { user_preference: { import_claude_prompt_template: template } },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "import_claude_prompt_template")).to eq(template)

      get "/api/user_preferences", headers: headers
      expect(JSON.parse(response.body).dig("data", "import_claude_prompt_template")).to eq(template)
    end

    it "clears template with JSON null" do
      UserPreference.create!(owner_key: "development", import_claude_prompt_template: "keep")

      patch "/api/user_preferences",
            params: { user_preference: { import_claude_prompt_template: nil } },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(UserPreference.find_by(owner_key: "development").import_claude_prompt_template).to be_nil
    end
  end

  describe "GET/PATCH /api/preferences/import_prompt" do
    it "aliases the same controller as /api/user_preferences" do
      template = "z {{CATALOG}} {{PAYMENT_METHOD_NAME}} {{EXAMPLE_MINOR_ID}}"

      patch "/api/preferences/import_prompt",
            params: { user_preference: { import_claude_prompt_template: template } },
            headers: headers

      expect(response).to have_http_status(:ok)

      get "/api/preferences/import_prompt", headers: headers
      expect(JSON.parse(response.body).dig("data", "import_claude_prompt_template")).to eq(template)

      get "/api/user_preferences", headers: headers
      expect(JSON.parse(response.body).dig("data", "import_claude_prompt_template")).to eq(template)
    end
  end
end
