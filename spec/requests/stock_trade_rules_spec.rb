# frozen_string_literal: true

require "rails_helper"

RSpec.describe "StockTradeRules", type: :request do
  describe "GET /stocks/trade-rules" do
    it "shows the singleton rule with updated date" do
      rule = StockTradeRule.instance
      rule.update!(body: "損切りは2%")

      get stock_trade_rule_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("取引ルール")
      expect(response.body).to include("損切りは2%")
      expect(response.body).to include("更新日 #{rule.reload.updated_on_label}")
      expect(rule.updated_on_label).to match(%r{\A\d{4}/\d{2}/\d{2}\z})
    end
  end

  describe "PATCH /stocks/trade-rules" do
    it "updates the singleton rule" do
      StockTradeRule.instance

      patch stock_trade_rule_path, params: {
        stock_trade_rule: { body: "利確は+10%" }
      }

      expect(response).to redirect_to(stock_trade_rule_path)
      expect(StockTradeRule.count).to eq(1)
      expect(StockTradeRule.instance.body).to eq("利確は+10%")
    end
  end
end
