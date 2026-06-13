# frozen_string_literal: true

require "rails_helper"

RSpec.describe StockCsvImporter do
  it "imports UTF-8 CSV exported from spreadsheets (銘柄名, コード, 業種)" do
    csv = <<~CSV
      銘柄名,コード,業種
      ニッスイ,1332,水産・農林業
    CSV

    result = described_class.import!(StringIO.new(csv))

    expect(result.skipped_rows).to eq(0)
    expect(result.created_stocks).to eq(1)
    expect(result.created_industries).to eq(1)

    stock = Stock.find_by!(code: "1332")
    expect(stock.name).to eq("ニッスイ")
    expect(stock.industry.name).to eq("水産・農林業")
  end
end
