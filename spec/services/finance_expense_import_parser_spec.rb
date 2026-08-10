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
      amazon = create(:payment_method, name: "Amazonカード", method_type: "card")
      rows = parse([ { date: "2026-07-20", month: "2026-07", card_id: "smcc_amazon", minor_category_id: minor.id, amount: 4500, memo: "test", source_id: "abc" } ].to_json)
      expect(rows.first.month_label).to eq("2026-07")
      expect(rows.first.amount).to eq(4500)
      expect(rows.first.memo).to eq("test")
      expect(rows.first.card_id).to eq("smcc_amazon")
      expect(rows.first.card_name).to eq("Amazonカード")
      expect(rows.first.payment_method_id).to eq(amazon.id)
    end

    it "allows negative amounts for refunds" do
      create(:payment_method, name: "PayPayカード", method_type: "card")
      rows = parse([ { month: "2026-07", card_id: "paypay_jcb", minor_category_id: minor.id, amount: -500, memo: "[返金] test" } ].to_json)
      expect(rows.first.amount).to eq(-500)
    end

    it "keeps unknown card_id without requiring a matching payment method" do
      rows = parse([ { month: "2026-07", card_id: "mystery_card", minor_category_id: minor.id, amount: 100, memo: "x" } ].to_json)
      expect(rows.first.card_id).to eq("mystery_card")
      expect(rows.first.payment_method_id).to be_nil
      expect(rows.first.card_name).to eq("mystery_card")
    end

    it "parses known card_id even when payment method master is absent" do
      rows = parse([ { month: "2026-07", card_id: "smcc_amazon", minor_category_id: minor.id, amount: 200, memo: "no pm" } ].to_json)
      expect(rows.first.card_id).to eq("smcc_amazon")
      expect(rows.first.payment_method_id).to be_nil
      expect(rows.first.card_name).to eq("Amazonカード")
    end
  end
end
