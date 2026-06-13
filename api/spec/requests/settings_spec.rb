require "rails_helper"

RSpec.describe "Settings", type: :request do
  describe "GET /finance/settings" do
    it "shows settings form" do
      get finance_settings_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("実績取込（Claude 用プロンプト）")
      expect(response.body).to include(ImportPromptTemplate::PLACEHOLDERS[:catalog])
    end
  end

  describe "PATCH /finance/settings" do
    let(:valid_template) do
      ImportPromptTemplate::DEFAULT
    end

    it "saves custom import prompt" do
      patch finance_settings_path, params: {
        user_preference: { import_claude_prompt_template: valid_template }
      }
      expect(response).to redirect_to(finance_settings_path)
      row = UserPreference.find_by(owner_key: "development")
      expect(row.import_claude_prompt_template).to be_nil
    end

    it "rejects template missing placeholders" do
      patch finance_settings_path, params: {
        user_preference: { import_claude_prompt_template: "invalid" }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("{{CATALOG}}")
    end
  end
end
