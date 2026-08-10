# frozen_string_literal: true

require "rails_helper"

RSpec.describe FinanceExpenseImportParser do
  let!(:minor) { create(:minor_category) }
  let(:expense_minors) { MinorCategory.includes(:major_category).where(id: minor.id) }

  def parse(raw)
    described_class.new(raw_json: raw, expense_minors: expense_minors).call
  end

  describe ".extract_json_payload" do
    it "strips verification block after ---" do
      raw = <<~TEXT
        [{"month":"2026-07","minor_category_id":#{minor.id},"amount":100,"memo":"x"}]
        ---
        総合計: 100
      TEXT
      expect(described_class.extract_json_payload(raw)).to start_with("[")
      expect(described_class.extract_json_payload(raw)).not_to include("総合計")
    end

    it "strips markdown code fences" do
      raw = <<~TEXT
        ```json
        [{"month":"2026-07","minor_category_id":#{minor.id},"amount":100,"memo":""}]
        ```
      TEXT
      expect(JSON.parse(described_class.extract_json_payload(raw))).to be_an(Array)
    end
  end

  describe "#call" do
    it "parses date and month fields" do
      rows = parse([ { date: "2026-07-20", month: "2026-07", minor_category_id: minor.id, amount: 4500, memo: "test", source_id: "abc" } ].to_json)
      expect(rows.first.month_label).to eq("2026-07")
      expect(rows.first.amount).to eq(4500)
      expect(rows.first.memo).to eq("test")
    end
  end
end
