require "rails_helper"

RSpec.describe "AiScripts", type: :request do
  describe "GET /stocks/ai-scripts" do
    it "shows index" do
      AiScript.create!(version_name: "v1", prompt: "prompt body")
      get ai_scripts_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("AI スクリプト一覧")
      expect(response.body).to include("v1")
    end
  end

  describe "POST /stocks/ai-scripts" do
    it "creates script" do
      post ai_scripts_path, params: { ai_script: { version_name: "v2", prompt: "new prompt" } }
      expect(response).to redirect_to(ai_scripts_path)
      expect(AiScript.find_by(version_name: "v2")).to be_present
    end
  end
end
