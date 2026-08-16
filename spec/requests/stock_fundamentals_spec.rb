# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Stock fundamentals analysis", type: :request do
  it "shows the default prompt and current watch stocks" do
    watched = create_test_stock(code: "4444", name: "本日監視")
    create_test_watch_period(stock: watched, starts_on: Date.current, ends_on: Date.current + 4)
    holding = create_test_stock(code: "1111", name: "保有のみ")
    create_test_entry(stock: holding)

    get stock_fundamentals_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("需給/決算を分析")
    expect(response.body).to include("チャートからは見えない決算・需給リスク")
    expect(response.body).to include("調査対象は「# 対象監視銘柄」")
    expect(response.body).to include("{{WATCH_STOCKS}}")
    expect(response.body).to include("プロンプトコピー")
    expect(response.body).to include("需給を取得")
    expect(response.body).to include("https://www.jpx.co.jp/markets/statistics-equities/margin/05.html")
    expect(response.body).to include("4444 本日監視")
    expect(response.body).to include(%(href="#{stock_path(watched)}"))
    expect(response.body).to include("1件")
    expect(response.body).to include("# 対象監視銘柄")
    expect(response.body).to include("data-copy-source=\"#stock-fundamentals-prompt\"")
    expect(response.body).to include("data-copy-fill-token=\"{{WATCH_STOCKS}}\"")
    expect(response.body).to match(/# 対象監視銘柄\s+\{\{WATCH_STOCKS\}\}\s+⚑が1つ以上付いた銘柄/m)
    expect(response.body).to include("4444 本日監視")
    expect(response.body).not_to include("保有のみ")
    expect(response.body).not_to include("仮説プロンプト")
  end

  it "shows watch stocks for the requested period" do
    watched = create_test_stock(code: "4444", name: "期間監視")
    other = create_test_stock(code: "5555", name: "別期間")
    create_test_watch_period(stock: watched, starts_on: Date.new(2026, 8, 10), ends_on: Date.new(2026, 8, 14))
    create_test_watch_period(stock: other, starts_on: Date.new(2026, 8, 17), ends_on: Date.new(2026, 8, 21))

    get stock_fundamentals_path(starts_on: "2026-08-10", ends_on: "2026-08-14")
    expect(response.body).to include("監視銘柄（8/10〜8/14）")
    expect(response.body).to include("<details")
    expect(response.body).to include("<summary")
    expect(response.body).to include("1件")
    expect(response.body).to include("期間監視")
    expect(response.body).not_to include("別期間")
  end

  it "saves a custom prompt without changing daily note prompts" do
    patch stock_fundamentals_path, params: {
      starts_on: "2026-08-10",
      ends_on: "2026-08-14",
      stock_fundamentals: { prompt: "カスタム需給プロンプト" }
    }
    expect(response).to redirect_to(stock_fundamentals_path(starts_on: "2026-08-10", ends_on: "2026-08-14"))

    preference = UserPreference.find_by!(owner_key: "development")
    expect(preference.stock_fundamentals_prompt).to eq("カスタム需給プロンプト")
    expect(preference.stock_daily_hypothesis_prompt).to be_nil
  end

  it "keeps the watch stocks placeholder when saving the prompt" do
    patch stock_fundamentals_path, params: {
      stock_fundamentals: { prompt: "カスタム需給プロンプト\n\n# 対象監視銘柄\n{{WATCH_STOCKS}}" }
    }
    expect(UserPreference.find_by!(owner_key: "development").stock_fundamentals_prompt)
      .to eq("カスタム需給プロンプト\n\n# 対象監視銘柄\n{{WATCH_STOCKS}}")
  end
end
