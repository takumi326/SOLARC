# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Omitted AI trade features", type: :request do
  it "hides AI nav links by default" do
    get stocks_path
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("仮想取引（AI）")
    expect(response.body).not_to include(">AI スクリプト<")
  end

  it "redirects virtual-ai trades list" do
    get stock_trades_path(mode: "virtual-ai")
    expect(response).to redirect_to(stocks_path)
    expect(flash[:alert]).to include("オミット")
  end
end
