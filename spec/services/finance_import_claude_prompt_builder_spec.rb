# frozen_string_literal: true

require "rails_helper"

RSpec.describe FinanceImportClaudePromptBuilder do
  let!(:minor) { create(:minor_category) }
  let!(:amazon_card) { create(:payment_method, name: "Amazonカード", method_type: "card") }
  let!(:paypay_card) { create(:payment_method, name: "PayPayカード", method_type: "card") }

  it "injects all cards and workflow into the default template" do
    prompt = described_class.build(
      catalog: "- id #{minor.id}: test",
      example_minor_id: minor.id,
      month: "2026-07"
    )

    expect(prompt).to include("smcc_amazon")
    expect(prompt).to include("paypay_jcb")
    expect(prompt).to include("JSON 配列1本")
    expect(prompt).not_to include("{{CARDS}}")
    expect(prompt).not_to include("{{TARGET_MONTH}}")
  end
end
