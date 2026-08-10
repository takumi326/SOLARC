# frozen_string_literal: true

require "rails_helper"

RSpec.describe FinanceImportGapCheckPromptBuilder do
  ParsedRow = FinanceExpenseImportParser::ParsedRow

  let!(:amazon) { create(:payment_method, name: "Amazonカード", method_type: "card") }
  let!(:minor) { create(:minor_category) }

  it "builds a prompt that asks Claude to use attached screenshots" do
    pending = [
      ParsedRow.new(
        line_number: 1,
        month_date: Date.new(2026, 7, 1),
        month_label: "2026-07",
        category_path: "食費 / 外食",
        amount: 1000,
        memo: "test",
        minor_category_id: minor.id,
        source_id: "abc",
        card_id: "smcc_amazon",
        card_name: amazon.name,
        payment_method_id: amazon.id
      )
    ]
    prompt = described_class.build(
      month: "2026-07",
      existing_rows: [],
      pending_rows: pending,
      selected_line_numbers: [ 1 ],
      duplicate_line_numbers: Set.new,
      catalog: "- id #{minor.id}: 食費 / 外食",
      example_minor_id: minor.id
    )

    expect(prompt).to include("スクショ")
    expect(prompt).to include("2026-07")
    expect(prompt).to include("status=pending")
    expect(prompt).to include("smcc_amazon")
    expect(prompt).to include("[不足追加]")
  end
end
