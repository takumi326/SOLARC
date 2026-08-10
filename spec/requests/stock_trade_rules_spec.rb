# frozen_string_literal: true

require "rails_helper"

RSpec.describe "StockTradeRules", type: :request do
  describe "GET /stocks/trade-rules" do
    it "shows index" do
      StockTradeRule.create!(title: "損切りルール", body: "2% 下回ったら即撤退")
      get stock_trade_rules_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("取引ルール")
      expect(response.body).to include("損切りルール")
    end
  end

  describe "POST /stocks/trade-rules" do
    it "creates rule" do
      post stock_trade_rules_path, params: {
        stock_trade_rule: { title: "利確ルール", body: "+10% で半分利確" }
      }

      expect(response).to redirect_to(stock_trade_rule_path(StockTradeRule.last))
      expect(StockTradeRule.find_by(title: "利確ルール")).to be_present
    end
  end

  describe "GET /stocks/trade-rules/:id" do
    it "shows rule" do
      rule = StockTradeRule.create!(title: "エントリー条件", body: "出来高増加を確認")
      get stock_trade_rule_path(rule)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("エントリー条件")
      expect(response.body).to include("出来高増加を確認")
    end
  end

  describe "PATCH /stocks/trade-rules/:id" do
    it "updates rule" do
      rule = StockTradeRule.create!(title: "旧タイトル", body: "旧本文")
      patch stock_trade_rule_path(rule), params: {
        stock_trade_rule: { title: "新タイトル", body: "新本文" }
      }

      expect(response).to redirect_to(stock_trade_rule_path(rule))
      expect(rule.reload.title).to eq("新タイトル")
    end
  end

  describe "DELETE /stocks/trade-rules/:id" do
    it "destroys rule" do
      rule = StockTradeRule.create!(title: "削除対象", body: "本文")
      delete stock_trade_rule_path(rule)

      expect(response).to redirect_to(stock_trade_rules_path)
      expect(StockTradeRule.find_by(id: rule.id)).to be_nil
    end
  end
end
