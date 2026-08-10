# frozen_string_literal: true

require "rails_helper"

RSpec.describe FinanceExpenseImportService do
  let!(:minor) { create(:minor_category) }
  let!(:amazon_card) { create(:payment_method, name: "Amazonカード", method_type: "card") }

  def build_row(**attrs)
    FinanceExpenseImportParser::ParsedRow.new(
      {
        line_number: 1,
        month_label: "2026-05",
        month_date: Date.new(2026, 5, 1),
        card_id: "smcc_amazon",
        card_name: "Amazonカード",
        minor_category_id: minor.id,
        category_path: "#{minor.major_category.name} / #{minor.name}",
        amount: 1000,
        memo: "test",
        payment_method_id: amazon_card.id
      }.merge(attrs)
    )
  end

  it "imports a row with the given payment method" do
    result = described_class.new(rows: [ build_row ]).call

    expect(result.imported_count).to eq(1)
    expect(Expense.order(:id).last.payment_method).to eq(amazon_card)
  end

  it "raises when payment_method_id is blank so the UI can ask for a choice" do
    expect {
      described_class.new(rows: [ build_row(payment_method_id: nil, card_id: "mystery") ]).call
    }.to raise_error(ArgumentError, /支払方法が未設定/)
  end
end
