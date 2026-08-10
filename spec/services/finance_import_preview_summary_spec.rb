# frozen_string_literal: true

require "rails_helper"

RSpec.describe FinanceImportPreviewSummary do
  ParsedRow = FinanceExpenseImportParser::ParsedRow

  def row(attrs = {})
    ParsedRow.new(
      line_number: 1,
      month_date: Date.new(2026, 7, 1),
      month_label: "2026-07",
      category_path: "食費 / 外食",
      amount: 1000,
      memo: "test",
      minor_category_id: 1,
      source_id: nil,
      **attrs
    )
  end

  describe ".verification_text" do
    it "extracts text after ---" do
      raw = "[{\"amount\":1}]\n---\n総合計: 100"
      expect(described_class.verification_text(raw)).to eq("総合計: 100")
    end
  end

  describe ".build" do
    it "summarizes totals and duplicates" do
      pending = [ row(line_number: 1, amount: 1000), row(line_number: 2, amount: 2000) ]
      duplicate = [ pending.first ]
      summary = described_class.build(pending_rows: pending, duplicate_rows: duplicate, compare_month: "2026-07")

      expect(summary.total_count).to eq(2)
      expect(summary.total_amount).to eq(3000)
      expect(summary.importable_count).to eq(1)
      expect(summary.importable_amount).to eq(2000)
      expect(summary.duplicate_count).to eq(1)
    end
  end

  describe ".classify_source" do
    it "detects paypal ids" do
      expect(described_class.classify_source("2WA22952EX114591B")).to eq(:paypal)
    end

    it "treats gmail ids as vpass" do
      expect(described_class.classify_source("18c5f2a3b4d5e6f7")).to eq(:vpass)
    end
  end
end
