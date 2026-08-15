# frozen_string_literal: true

require "rails_helper"

RSpec.describe "StockSettings", type: :request do
  describe "GET /stocks/settings" do
    it "shows the chart id setting" do
      StockSetting.instance.update!(tradingview_chart_id: "8WvKf6oB")

      get stock_setting_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("チャート ID")
      expect(response.body).to include("8WvKf6oB")
    end
  end

  describe "PATCH /stocks/settings" do
    it "updates the chart id" do
      StockSetting.instance

      patch stock_setting_path, params: {
        stock_setting: { tradingview_chart_id: "Abcd1234" }
      }

      expect(response).to redirect_to(stock_setting_path)
      expect(StockSetting.tradingview_chart_id).to eq("Abcd1234")
    end
  end
end
