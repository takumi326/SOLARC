# frozen_string_literal: true

module StockTestHelpers
  def create_test_stock(code: "7203", name: "トヨタ", industry_name: "輸送用機器")
    industry = Industry.find_or_create_by!(name: industry_name)
    Stock.create!(code: code, name: name, industry: industry)
  end

  def create_test_entry(stock:, **attrs)
    Entry.create!({
      stock: stock,
      trade_type: "real",
      judgment_type: "human",
      entry_reason: "テストエントリー",
      traded_at: Date.current,
      shares: 100
    }.merge(attrs))
  end
end

RSpec.configure do |config|
  config.include StockTestHelpers
end
