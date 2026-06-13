require "rails_helper"

RSpec.describe "Industries", type: :request do
  describe "GET /stocks/industries" do
    it "shows industry list" do
      Industry.find_or_create_by!(name: "テスト業種")

      get industries_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("業種（カスタム追加）")
      expect(response.body).to include("テスト業種")
    end
  end

  describe "POST /stocks/industries" do
    it "creates industry" do
      post industries_path, params: { industry: { name: "新規カスタム業種" } }
      expect(response).to redirect_to(industries_path)
      expect(Industry.find_by(name: "新規カスタム業種")).to be_present
    end
  end
end
