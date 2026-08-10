# frozen_string_literal: true

require "rails_helper"

RSpec.describe "AiScripts", type: :request do
  describe "when AI trade features are omitted" do
    it "redirects index away from AI scripts" do
      AiScript.create!(version_name: "v1", prompt: "prompt body")
      get ai_scripts_path
      expect(response).to redirect_to(stocks_path)
      expect(flash[:alert]).to include("オミット")
    end

    it "redirects create away from AI scripts" do
      post ai_scripts_path, params: { ai_script: { version_name: "v2", prompt: "new prompt" } }
      expect(response).to redirect_to(stocks_path)
      expect(AiScript.find_by(version_name: "v2")).to be_nil
    end
  end

  describe "when AI trade features are enabled", type: :request do
    around do |example|
      previous = ENV["AI_TRADE_FEATURES"]
      ENV["AI_TRADE_FEATURES"] = "true"
      example.run
    ensure
      ENV["AI_TRADE_FEATURES"] = previous
    end

    it "shows index" do
      AiScript.create!(version_name: "v1", prompt: "prompt body")
      get ai_scripts_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("AI スクリプト一覧")
      expect(response.body).to include("v1")
    end

    it "creates script" do
      post ai_scripts_path, params: { ai_script: { version_name: "v2", prompt: "new prompt" } }
      expect(response).to redirect_to(ai_scripts_path)
      expect(AiScript.find_by(version_name: "v2")).to be_present
    end
  end
end
